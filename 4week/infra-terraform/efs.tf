resource "aws_efs_file_system" "efs" {
  creation_token = "my-product"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

data "aws_iam_policy_document" "efs" {
  statement {
    sid    = "efs-mount"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
    ]
    resources = [aws_efs_file_system.efs.arn]
  }
}

resource "aws_efs_file_system_policy" "efs" {
  file_system_id = aws_efs_file_system.efs.id
  policy         = data.aws_iam_policy_document.efs.json
}

resource "aws_efs_mount_target" "efs" {
  count = length(module.eks_vpc.public_subnets_id)
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = module.eks_vpc.public_subnets_id[count.index]
  security_groups = [
    data.aws_security_group.cluster.id
  ]
}
