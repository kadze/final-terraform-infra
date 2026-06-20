output "role_arn" {
  description = "ARN of the IAM role for the app's CSI secret access"
  value       = aws_iam_role.secrets_csi_app.arn
}

output "role_name" {
  description = "Name of the IAM role for the app's CSI secret access"
  value       = aws_iam_role.secrets_csi_app.name
}
