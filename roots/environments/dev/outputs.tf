output "grafana_cloudwatch_role_arn" {
  description = "ARN of the Grafana CloudWatch IRSA role — set as GRAFANA_CLOUDWATCH_IAM_ROLE_ARN on the dev GitHub environment"
  value       = module.grafana_cloudwatch_irsa.role_arn
}
