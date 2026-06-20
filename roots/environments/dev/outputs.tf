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
