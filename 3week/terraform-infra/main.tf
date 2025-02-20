terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.83.0"
    }
  }
  # required_version = ">= 1.2.0"
}

provider "aws" {
  shared_config_files = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  default_tags {
    tags = {
      org = "aews"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}


module "eks_vpc" {
  source  = "./module/vpc"
  vpc_name = var.cluster_name
  vpc_cidr = "192.168.0.0/16"
  subnet_count = 3
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.1"
  cluster_name = var.cluster_name
  cluster_version = "1.31"

  vpc_id = module.eks_vpc.vpc_id
  subnet_ids = module.eks_vpc.public_subnets_id

  # fargate_profiles = {
  #   default = {
  #     name = "default"
  #     subnet_ids = module.eks_vpc.private_subnets
  #     selectors = [
  #       {
  #         namespace = "default"
  #         labels = {
  #           WorkerType = "fargate"
  #         }
  #       }
  #     ]
  #     tags = {
  #       Owner = "default"
  #     }
  #     timeouts = {
  #       create = "20m"
  #       delete = "20m"
  #     }
  #   }
  # }

  # addon is in the file cluster_addon
  cluster_addons = {
    coredns = {
      mostd_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        enableNetworkPolicy : "true",
        env: {
            # "AWS_VPC_K8S_CNI_EXCLUDE_SNAT_CIDRS" : "172.20.0.0/16",
            # "AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG" : "true",
            # "ENI_CONFIG_LABEL_DEF" : "topology.kubernetes.io/zone",
            # "ENABLE_PREFIX_DELEGATION" : "true"
        }
      })
    }
  }
  # create = true
  create_node_security_group = true
  enable_cluster_creator_admin_permissions = true
  attach_cluster_encryption_policy = true
  enable_irsa = true
  # todo : check this role to whom attaches
  iam_role_additional_policies = {
    awsLoadBalancerController = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
    # certManager               = "arn:aws:iam::aws:policy/AmazonEKS_CertManagerPolicy"
    externalDNS               = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
    imageBuilder              = "arn:aws:iam::aws:policy/AWSImageBuilderFullAccess"
    eksCNI = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

  }
  node_iam_role_additional_policies = {
    eksCNI = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    awsLoadBalancerController = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
    # certManager               = "arn:aws:iam::aws:policy/AmazonEKS_CertManagerPolicy"
    externalDNS               = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
    imageBuilder              = "arn:aws:iam::aws:policy/AWSImageBuilderFullAccess"
  }
  cluster_security_group_additional_rules = merge(
    {
      peered_vpc_ingress = {
        type                       = "ingress"
        from_port                  = 0
        to_port                    = 0
        protocol                   = "-1"
        source_security_group_id = module.operator_vpc.default_sg_id
        description = "Allow ingress from peered VPC"
      }
    },
    {
      eks_vpc_ingress = {
        type                       = "ingress"
        from_port                  = 0
        to_port                    = 0
        protocol                   = "-1"
        source_security_group_id = module.eks_vpc.default_sg_id
        description = "Allow ingress from eks VPC"
      }
    },
    # {
    #   # Allow tcp/443 from the NLB IP addresses
    #   for i, ip_addr in data.dns_a_record_set.nlb.addrs : "nlb_ingress_${replace(ip_addr, ".", "")}" => {
    #     description = "Allow ingress from NLB"
    #     type        = "ingress"
    #     from_port   = 443
    #     to_port     = 443
    #     protocol    = "tcp"
    #     cidr_blocks = ["${ip_addr}/32"]
    #   }
    # }
  )
  node_security_group_additional_rules  = {
    peered_vpc_ingress = {
      type                       = "ingress"
      from_port                  = 0
      to_port                    = 0
      protocol                   = "-1"
      source_security_group_id = module.operator_vpc.default_sg_id
    }
  }

  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs = ["${local.my_pub_ip}/32"]
  cluster_endpoint_private_access = true

  depends_on = [
    module.eks_vpc,
    module.nlb,
    aws_lb_target_group.nlb,
    module.eventbridge,
    aws_cloudtrail.cloudtrail

  ]
}


# cluster primary security group
data "aws_security_group" "cluster" {
    id = module.eks.cluster_primary_security_group_id
}

resource "aws_security_group_rule" "allow_operator" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"  # 모든 프로토콜 허용
  security_group_id        = data.aws_security_group.cluster.id
  source_security_group_id = module.operator_vpc.default_sg_id
  description              = "Allow inbound traffic from operator VPC default security group"
}



