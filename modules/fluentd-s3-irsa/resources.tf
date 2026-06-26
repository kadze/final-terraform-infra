resource "aws_s3_bucket" "logs" {
  bucket = local.log_bucket_name

  tags = {
    component = "logging"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy: expire log objects after the configured retention period.
# This is the cost guard for dev — unbounded retention grows the S3 bill silently.
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-log-objects"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }
  }
}

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
        Sid    = "S3PutLogs"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.logs.arn}/*"
      },
      {
        # Required by the S3 output plugin to determine the bucket region.
        Sid    = "S3GetBucketLocation"
        Effect = "Allow"
        Action = ["s3:GetBucketLocation"]
        Resource = aws_s3_bucket.logs.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fluentd_s3" {
  role       = aws_iam_role.fluentd_s3.name
  policy_arn = aws_iam_policy.fluentd_s3.arn
}
