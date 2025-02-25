locals {
  trail_name = "trail_eks_owned_eni"

  cluster_auth_base64               = module.eks.cluster_certificate_authority_data
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_name = var.cluster_name
  region = "ap-northeast-2"
  user_arn = data.aws_caller_identity.current.arn
  my_pub_ip = chomp(data.http.my_ip.response_body)

  kubeconfig = templatefile("${path.module}/templates/kubeconfig.tpl", { 
    cluster_name                            = local.cluster_name
    kubeconfig_name                         = "cluster_eks"
    endpoint                                = local.cluster_endpoint
    cluster_auth_base64                     = local.cluster_auth_base64
    region = local.region
    user_arn = local.user_arn
  })
}
