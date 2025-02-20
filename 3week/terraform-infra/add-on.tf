resource "aws_eks_addon" "ebs-csi" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version = "v1.39.0-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  configuration_values = jsonencode({
    defaultStorageClass = {
      enabled = true
    }
    node = {
      volumeAttachLimit = 31
      enableMetrics = true
    }
    # controller = {
    #   serviceAccount = {
    #     annotations = {
    #       # "eks.amazonaws.com/role-arn" = module.ebs_csi_irsa.iam_role_arn
    #       "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ebs-csi"
    #     }
    #   }
    # }
  })
  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"

  attach_ebs_csi_policy = true
  force_detach_policies = true

  role_name = "ebs-csi"

  oidc_providers = {
    eks = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
