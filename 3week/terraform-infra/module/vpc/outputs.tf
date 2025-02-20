output "vpc_id" {
   value = aws_vpc.vpc.id
   description = "vpcid"
}
output "vpc_cidr" {
  value = aws_vpc.vpc.cidr_block
}
output "default_sg_id" {
  value = aws_vpc.vpc.default_security_group_id
}


output "public_subnets_cidr" {
  value = local.public_subnets
  description = "public_subnets_cidr"
}
output "public_subnets_id" {
  value = values(aws_subnet.public_subnet)[*].id
  description = "public_subnets_id"
}

output "private_subnets_cidr" {
  value = local.private_subnets
  description = "private_subnets_cidr"
}
output "private_subnets_id" {
  value = values(aws_subnet.private_subnet)[*].id
  description = "private_subnets_id"
}

output "pub_route_table" {
  value = aws_route_table.pub_route_table
}
output "priv_route_table" {
  value = aws_route_table.private_route_table
}


