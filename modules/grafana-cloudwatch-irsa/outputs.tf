output "role_arn" {
  description = "ARN of the IAM role for Grafana to read CloudWatch"
  value       = aws_iam_role.grafana_cloudwatch.arn
}

output "role_name" {
  description = "Name of the IAM role for Grafana CloudWatch access"
  value       = aws_iam_role.grafana_cloudwatch.name
}
