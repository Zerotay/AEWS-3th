locals {
  public_subnets = [
    for i in range(var.subnet_count) :
    cidrsubnet(var.vpc_cidr, 8, i)
  ]

  private_subnets = [
    for i in range(var.subnet_count) :
    cidrsubnet(var.vpc_cidr, 8, 10+i)
  ]
}
