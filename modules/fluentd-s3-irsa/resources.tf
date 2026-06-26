resource "aws_iam_role" "fluentd_s3" {
  name = "fluentd-s3-irsa-${var.cluster_name}"

  tags = {
    component = "logging"
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${local.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "fluentd_s3" {
  name        = "fluentd-s3-policy-${var.cluster_name}"
  description = "Allows Fluentd to write log objects to the backup S3 bucket"

  tags = {
    component = "logging"
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3PutLogs"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "arn:aws:s3:::${local.log_bucket_name}/*"
      },
      {
        # Required by the S3 output plugin to determine the bucket region.
        Sid      = "S3GetBucketLocation"
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation"]
        Resource = "arn:aws:s3:::${local.log_bucket_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fluentd_s3" {
  role       = aws_iam_role.fluentd_s3.name
  policy_arn = aws_iam_policy.fluentd_s3.arn
}
