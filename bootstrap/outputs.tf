output "gha_terraform_role_arn" {
  description = "Set this as IAM_ROLE on the dev GitHub environment."
  value       = aws_iam_role.gha_terraform.arn
}
