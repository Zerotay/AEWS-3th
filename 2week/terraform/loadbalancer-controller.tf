locals {
  lbc_name_in_aws = "AWSLoadBalancerController"
  lbc_name_in_cluster = "aws-load-balancer-controller"
  lbc_namespace = "kube-system"

}

provider "helm" {
  kubernetes {
    config_path = "./kubeconfig"
  }
}

resource "helm_release" "lbc" {
  name       = local.lbc_name_in_cluster
  repository = "https://aws.github.io/eks-charts"
  chart      = local.lbc_name_in_cluster

  namespace = local.lbc_namespace

  set {
    name = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name = "region"
    value = data.aws_region.current.name
  }
  set {
    name = "vpcId"
    value = module.eks_vpc.vpc_id
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lbc.arn
  }
}



data "http" "lbc" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json"
}
resource "aws_iam_policy" "lbc" {
  name        = "${local.lbc_name_in_aws}IAMPolicy"
  description = "IAM Policy for AWS Load Balancer Controller"
  policy      = data.http.lbc.response_body
}

data "aws_iam_policy_document" "lbc" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${local.lbc_namespace}:${local.lbc_name_in_cluster}",
      ]
    }
    effect = "Allow"
  }
}
resource "aws_iam_role" "lbc" {
  name               = "${local.lbc_name_in_aws}IAM"
  assume_role_policy = data.aws_iam_policy_document.lbc.json
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}
