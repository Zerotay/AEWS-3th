#############
##### VPC CNI
#############
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  addon_version = "v1.19.2-eksbuild.5"
  resolve_conflicts_on_update = "PRESERVE"
  configuration_values = jsonencode({
    enableNetworkPolicy : "true",
    env: {
        # "AWS_VPC_K8S_CNI_EXCLUDE_SNAT_CIDRS" : "172.20.0.0/16",
        # "AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG" : "true",
        # "ENI_CONFIG_LABEL_DEF" : "topology.kubernetes.io/zone",
        "ENABLE_PREFIX_DELEGATION" : "true"
    }
  })
  service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
}
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"
  role_name                      = "vpc-cni"

  attach_vpc_cni_policy          = true
  vpc_cni_enable_ipv4            = true
  vpc_cni_enable_cloudwatch_logs = true

  force_detach_policies = true
  oidc_providers = {
    eks = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}
#############
##### AWS EBS CSI Driver
#############
resource "aws_eks_addon" "ebs_csi" {
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
  })
  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"
  role_name = "ebs-csi"

  attach_ebs_csi_policy = true
  force_detach_policies = true

  oidc_providers = {
    eks = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

#############
##### AWS EFS CSI Driver
#############
resource "aws_eks_addon" "efs_csi" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-efs-csi-driver"
  addon_version = "v2.1.4-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  configuration_values = jsonencode({ })
  service_account_role_arn = module.efs_csi_irsa.iam_role_arn
}

module "efs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"
  role_name = "efs-csi"

  attach_efs_csi_policy = true
  force_detach_policies = true

  oidc_providers = {
    eks = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}
