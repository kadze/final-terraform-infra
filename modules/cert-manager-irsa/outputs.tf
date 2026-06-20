output "role_arn" {
  description = "ARN of the IAM role for cert-manager"
  value       = aws_iam_role.cert_manager.arn
}

output "role_name" {
  description = "Name of the IAM role for cert-manager"
  value       = aws_iam_role.cert_manager.name
}
