output "db_instance_identifier" {
  description = "RDS instance identifier — consumed by Story 2.3's CloudWatch alarm module"
  value       = aws_db_instance.main.identifier
}

output "db_endpoint" {
  description = "RDS instance hostname for the app connection secret"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed master password secret in Secrets Manager"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
