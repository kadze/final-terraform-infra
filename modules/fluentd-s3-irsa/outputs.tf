output "role_arn" {
  description = "ARN of the IAM role for Fluentd to write logs to S3 — set as FLUENTD_S3_IAM_ROLE_ARN on the dev GitHub environment"
  value       = aws_iam_role.fluentd_s3.arn
}

output "role_name" {
  description = "Name of the IAM role for Fluentd S3 access"
  value       = aws_iam_role.fluentd_s3.name
}

output "bucket_name" {
  description = "Name of the S3 bucket receiving Fluentd log backups — set as LOG_BUCKET_NAME on the dev GitHub environment"
  value       = aws_s3_bucket.logs.id
}

output "bucket_arn" {
  description = "ARN of the S3 log backup bucket"
  value       = aws_s3_bucket.logs.arn
}
