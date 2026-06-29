output "role_arn" {
  description = "ARN of the GHA role — set as IAM_ROLE on the app's GitHub environment"
  value       = aws_iam_role.app_gha.arn
}

output "role_name" {
  description = "Name of the GHA role"
  value       = aws_iam_role.app_gha.name
}
