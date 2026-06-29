output "grafana_cloudwatch_role_arn" {
  description = "ARN of the Grafana CloudWatch IRSA role — set as GRAFANA_CLOUDWATCH_IAM_ROLE_ARN on the dev GitHub environment"
  value       = module.grafana_cloudwatch_irsa.role_arn
}

output "cert_manager_role_arn" {
  description = "ARN of the cert-manager IRSA role — set as CERT_MANAGER_IAM_ROLE_ARN on the dev GitHub environment"
  value       = module.cert_manager_irsa.role_arn
}

output "external_dns_role_arn" {
  description = "ARN of the external-dns IRSA role — set as EXTERNAL_DNS_IAM_ROLE_ARN on the dev GitHub environment"
  value       = module.external_dns_irsa.role_arn
}

output "fluentd_s3_role_arn" {
  description = "ARN of the Fluentd S3 IRSA role — set as FLUENTD_S3_IAM_ROLE_ARN on the dev GitHub environment"
  value       = module.fluentd_s3_irsa.role_arn
}

output "log_bucket_name" {
  description = "S3 bucket receiving Fluentd log backups — set as LOG_BUCKET_NAME on the dev GitHub environment"
  value       = module.fluentd_s3_irsa.bucket_name
}

output "versus_db_instance_identifier" {
  description = "RDS instance identifier for Versus — consumed by Story 2.3's CloudWatch alarm module"
  value       = module.rds_mysql_versus.db_instance_identifier
}

output "versus_db_endpoint" {
  description = "RDS hostname for Versus — use when populating the versus/db-credentials secret"
  value       = module.rds_mysql_versus.db_endpoint
}

output "versus_master_user_secret_arn" {
  description = "ARN of the RDS-managed master password secret — use to retrieve the password for the app-shaped secret"
  value       = module.rds_mysql_versus.master_user_secret_arn
}

output "versus_gha_role_arn" {
  description = "ARN of the versus GHA role — set as IAM_ROLE on the kadze-versus dev GitHub environment"
  value       = module.versus_gha_role.role_arn
}
