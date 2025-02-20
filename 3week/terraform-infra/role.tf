# locals {
#   ebs_name_in_aws = "EBSCSIDriver"
#   ebs_name_in_cluster = "ebs-csi-controller-sa"
#   namespace = "kube-system"
# }

# data "aws_iam_policy_document" "ebs_csi" {
#   statement {
#     actions = ["sts:AssumeRoleWithWebIdentity"]
#     principals {
#       type        = "Federated"
#       identifiers = [module.eks.oidc_provider_arn]
#       # identifiers = [data.aws_iam_openid_connect_provider.this.arn]
#     }

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
#       values = [
#         "system:serviceaccount:${local.namespace}:${local.ebs_name_in_cluster}",
#       ]
#     }
#     effect = "Allow"
#   }
# }

# resource "aws_iam_role" "ebs_csi" {
#   name               = "${local.ebs_name_in_aws}Role"
#   assume_role_policy = data.aws_iam_policy_document.ebs_csi.json
# }

# resource "aws_iam_role_policy_attachment" "ebs_csi" {
#   role       = aws_iam_role.ebs_csi.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
# }


module "efs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.52.2"

  attach_ebs_csi_policy = true
  force_detach_policies = true

  role_name = "efs-csi"

  oidc_providers = {
    eks = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}
