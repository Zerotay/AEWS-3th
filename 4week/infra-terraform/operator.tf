###############################################################################
# operator vpc setting
###############################################################################
module "operator_vpc" {
  source  = "./module/vpc"
  vpc_name = "operator"
  vpc_cidr = "172.20.0.0/16"
  subnet_count = 1
}
resource "aws_vpc_peering_connection" "peering" {
  vpc_id = module.eks_vpc.vpc_id
  peer_vpc_id = module.operator_vpc.vpc_id
  auto_accept = true
  tags = {
    Name = "VPCPeering-EksVPC-OpsVPC"
  }
}

resource "aws_route" "peering_eks" {
  route_table_id = module.eks_vpc.pub_route_table.id
  destination_cidr_block = module.operator_vpc.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
}
resource "aws_route" "peering_ops" {
  route_table_id = module.operator_vpc.pub_route_table.id
  destination_cidr_block = module.eks_vpc.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
}
###############################################################################
# operator host setting
###############################################################################
resource "aws_instance" "operator" {
  ami = "ami-037f2fa59e7cfbbbb"
  instance_type   = "t3.medium"
  subnet_id = module.operator_vpc.public_subnets_id[0]
  key_name = aws_key_pair.eks_key_pair.key_name
  vpc_security_group_ids = [
    aws_security_group.operator_host_sg.id,
    module.operator_vpc.default_sg_id
  ]
  # enable ssm
  iam_instance_profile   = aws_iam_instance_profile.operator.name
  tags = {
    Name = "operator-host"
  }
  # default setting for operation
  user_data = templatefile("${path.module}/templates/userdata.tpl", { 
    aws_credentials = file("~/.aws/credentials")
    aws_config = file("~/.aws/config")
    cluster_name                            = local.cluster_name
    endpoint                                = local.cluster_endpoint
    cluster_auth_base64                     = local.cluster_auth_base64
    region = local.region
    user_arn = local.user_arn
    kubeconfig = local.kubeconfig
    ssh_key = tls_private_key.ssh_key.private_key_pem
  })
  depends_on = [
    aws_iam_role_policy_attachment.operator
  ]
}

# allow ssh from my local
resource "aws_security_group" "operator_host_sg" {
  vpc_id = module.operator_vpc.vpc_id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${local.my_pub_ip}/32"]  
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "operator-host-sg"
  }
}

resource "aws_iam_role" "operator" {
  name = "ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "operator" {
  role       = aws_iam_role.operator.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "operator" {
  name = "operator-profile"
  role = aws_iam_role.operator.name
}
