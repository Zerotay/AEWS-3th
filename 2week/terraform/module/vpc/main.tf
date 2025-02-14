terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # version = "5.86.0"
    }
  }
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

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  # instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags =  {
    Name = "${var.vpc_name}-VPC"
  }
}


resource "aws_subnet" "public_subnet" {
  for_each = { for idx, subnet in local.public_subnets: idx => subnet }

  vpc_id = aws_vpc.vpc.id
  availability_zone = var.azs[each.key]
  cidr_block =  each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-PublicSubnet${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private_subnet" {
  for_each = { for idx, subnet in local.private_subnets: idx => subnet }

  vpc_id = aws_vpc.vpc.id
  availability_zone = var.azs[each.key]
  cidr_block =  each.value

  tags = {
    Name = "${var.vpc_name}-PrivateSubnet${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_route_table" "pub_route_table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.vpc_name}-PublicRouteTable"
  }
}
resource "aws_route_table_association" "public_subnet_association" {
  for_each = {
    for subnet_key, subnet in aws_subnet.public_subnet : subnet_key => subnet
  }
  subnet_id      = each.value.id
  route_table_id = aws_route_table.pub_route_table.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}
resource "aws_route" "pubsubrt" {
  route_table_id = aws_route_table.pub_route_table.id
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.vpc_name}-PrivateRouteTable"
  }
}
resource "aws_route_table_association" "private_subnet_association" {
  for_each = {
    for subnet_key, subnet in aws_subnet.private_subnet : subnet_key => subnet
  }
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table.id
}
