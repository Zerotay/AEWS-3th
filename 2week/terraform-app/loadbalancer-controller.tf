locals {
  lbc_name_in_aws = "AWSLoadBalancerController"
  lbc_name_in_cluster = "aws-load-balancer-controller"
  lbc_namespace = "kube-system"

  cluster_name = "terraform-eks"
  vpc_name = "${local.cluster_name}-VPC"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}
data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}
data "aws_vpc" "this" {
  tags = {
    Name = local.vpc_name
  }
}

provider "aws" {
  shared_config_files = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
}
provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command = "aws"
      args = ["eks", "get-token", "--region", data.aws_region.current.name, "--cluster-name", local.cluster_name]
    }
  }
}

resource "helm_release" "lbc" {
  name       = local.lbc_name_in_cluster
  repository = "https://aws.github.io/eks-charts"
  chart      = local.lbc_name_in_cluster

  namespace = local.lbc_namespace

  set {
    name = "clusterName"
    value = local.cluster_name
  }
  set {
    name = "region"
    value = data.aws_region.current.name
  }
  set {
    name = "vpcId"
    value = data.aws_eks_cluster.this.vpc_config[0].vpc_id
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
      identifiers = [data.aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
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
