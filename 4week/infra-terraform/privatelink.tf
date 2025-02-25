module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.13.0"

  name               = local.cluster_name
  vpc_id             = module.eks_vpc.vpc_id
  subnets            = module.eks_vpc.public_subnets_id
  internal           = true
  load_balancer_type = "network"
  security_groups = [
    module.eks_vpc.default_sg_id
  ]

  enforce_security_group_inbound_rules_on_private_link_traffic = "off"
  enable_deletion_protection = false
}

resource "aws_lb_listener" "nlb" {
  load_balancer_arn = module.nlb.arn
  port              = "443"
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb.arn
  }
}
resource "aws_lb_target_group" "nlb" {
  name     = "${local.cluster_name}-tg"
  port     = 443
  protocol = "TCP"
  target_type = "ip"
  health_check  {
    enabled  = true
    path     = "/readyz"
    protocol = "HTTPS"
    matcher  = "200"
  }
  vpc_id   = module.eks_vpc.vpc_id
}


# domain name will be accectable only when lb created
data "dns_a_record_set" "nlb" {
  host = module.nlb.dns_name
}

resource "aws_vpc_endpoint_service" "this" {
  acceptance_required        = true
  network_load_balancer_arns = [module.nlb.arn]
}

# this resource will accept the connection between endpoint and the operator client
resource "aws_vpc_endpoint_connection_accepter" "this" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.this.id
  vpc_endpoint_id         = aws_vpc_endpoint.operator.id
  depends_on = [
    module.eks
  ]
}

################################################################################
# VPC Endpoint
################################################################################

locals {
  api_server_url_pattern = regex("(https://)([[:alnum:]]+\\.)(.*)", module.eks.cluster_endpoint)
  cluster_endpoint_subdomain = local.api_server_url_pattern[1]
  cluster_endpoint_domain    = local.api_server_url_pattern[2]
}

resource "aws_vpc_endpoint" "operator" {
  vpc_id             = module.operator_vpc.vpc_id
  service_name       = resource.aws_vpc_endpoint_service.this.service_name
  vpc_endpoint_type  = "Interface"
  subnet_ids         = module.operator_vpc.public_subnets_id
  security_group_ids = [aws_security_group.operator_vpc_endpoint.id]

  tags = { 
    Name = "operator-endpoint"
  }
}

resource "aws_security_group" "operator_vpc_endpoint" {
  vpc_id      = module.operator_vpc.vpc_id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.operator_vpc.vpc_cidr]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_route53_zone" "operator" {
  name    = local.cluster_endpoint_domain
  comment = "Private hosted zone for EKS API server endpoint"

  vpc { vpc_id = module.operator_vpc.vpc_id }
  tags = {
    Name = "operator_private_host_zone"
  }
}

resource "aws_route53_record" "client" {
  zone_id = aws_route53_zone.operator.zone_id
  name    = "${local.cluster_endpoint_subdomain}${local.cluster_endpoint_domain}"
  type    = "A"

  alias {
    name = aws_vpc_endpoint.operator.dns_entry[0].dns_name
    zone_id = aws_vpc_endpoint.operator.dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}

################################################################################
# Lambda - Create ENI IPs to NLB Target Group
################################################################################
module "create_eni_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 5.0"

  function_name = "${local.cluster_name}-add-eni-ips"
  description   = "Add ENI IPs to NLB target group when EKS API endpoint is created"
  source_path   = "lambdas"
  handler       = "create_eni.handler"
  runtime       = "python3.10"
  publish       = true
  attach_policy_json = true
  policy_json        = <<-EOT
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "elasticloadbalancing:RegisterTargets"
          ],
          "Resource": ["${aws_lb_target_group.nlb.arn}"]
        }
      ]
    }
  EOT
  environment_variables = {
    TARGET_GROUP_ARN = aws_lb_target_group.nlb.arn
  }
  allowed_triggers = {
    eventbridge = {
      principal  = "events.amazonaws.com"
      source_arn = module.eventbridge.eventbridge_rule_arns["eks-api-endpoint-create"]
    }
  }
  tags = {
    Name = "lambda-attaching_eni2tg"
  }
}
################################################################################
# Lambda - Delete ENI IPs from NLB Target Group
################################################################################
module "delete_eni_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 5.0"

  function_name = "${local.cluster_name}-delete-eni-ips"
  description   = "Deletes ENI IPs from NLB target group when EKS API endpoint is deleted"
  handler       = "delete_eni.handler"
  runtime       = "python3.10"
  publish       = true
  source_path   = "lambdas"
  attach_policy_json = true
  policy_json        = <<-EOT
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ec2:DescribeNetworkInterfaces",
            "elasticloadbalancing:Describe*"
          ],
          "Resource": ["*"]
        },
        {
          "Effect": "Allow",
          "Action": [
            "elasticloadbalancing:DeregisterTargets"
          ],
          "Resource": ["${aws_lb_target_group.nlb.arn}"]
        }
      ]
    }
  EOT
  environment_variables = {
    TARGET_GROUP_ARN = aws_lb_target_group.nlb.arn
    EKS_CLUSTER_NAME = local.cluster_name
  }
  allowed_triggers = {
    eventbridge = {
      principal  = "events.amazonaws.com"
      source_arn = module.eventbridge.eventbridge_rule_arns["eks-api-endpoint-delete"]
    }
  }
  tags = {
    Name = "lambda-detaching_eni4tg"
  }
}

################################################################################
# EventBridge Rules
################################################################################
module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "3.14.3"
  create_bus = false

  rules = {
    eks-api-endpoint-create = {
      description         = "trigger when eni created by eks"
      event_pattern = jsonencode({
        "detail" : {
          "eventSource" : ["ec2.amazonaws.com"],
          "eventName" : ["CreateNetworkInterface"],
          "sourceIPAddress" : ["eks.amazonaws.com"],
          "responseElements" : {
            "networkInterface" : {
              "description" : ["Amazon EKS ${local.cluster_name}"]
            }
          }
        }
      })
      enabled = true
    }
    eks-api-endpoint-delete = {
      description         = "Trigger for a Lambda"
      schedule_expression = "rate(15 minutes)"
    }
  }

  targets = {
    eks-api-endpoint-create = [{
        name = module.create_eni_lambda.lambda_function_name
        arn  = module.create_eni_lambda.lambda_function_arn
    }]
    eks-api-endpoint-delete = [{
        name = module.delete_eni_lambda.lambda_function_name
        arn  = module.delete_eni_lambda.lambda_function_arn
    }]
  }
  tags = {
    Name = "${local.cluster_name} eventbridge"
  }
}
