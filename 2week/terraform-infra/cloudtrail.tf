resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${local.cluster_name}-cloudtrail"
  force_destroy = true
}
data "aws_iam_policy_document" "cloudtrail" {
  version = "2012-10-17"
  statement {
    sid = "AWSCloudTrailAclCheck20150319"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["s3:GetBucketAcl"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}"]
    condition {
      test = "StringEquals"
      variable = "aws:SourceArn"
      values = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"]
    }
  }
  statement {
    sid = "AWSCloudTrailWrite20150319"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test = "StringEquals"
      variable = "s3:x-amz-acl"
      values = ["bucket-owner-full-control"]
    }
    condition {
      test = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail.json
}

resource "aws_cloudtrail" "cloudtrail" {
  name = local.trail_name
  s3_bucket_name = aws_s3_bucket.cloudtrail.id

  include_global_service_events = true
  is_multi_region_trail = true
  enable_logging = true

  advanced_event_selector {
    name = "eni_creation_selector"
    field_selector {
      field = "eventCategory"
      equals = ["Management"]
    }
    field_selector {
      field = "readOnly"
      equals = ["false"]
    }
  }
  depends_on = [
    aws_s3_bucket_policy.cloudtrail
  ]
}
