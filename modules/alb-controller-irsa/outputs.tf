output "role_arn" {
  description = "ARN of the IAM role for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "role_name" {
  description = "Name of the IAM role for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.name
}
