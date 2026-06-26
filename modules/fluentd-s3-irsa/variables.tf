variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster (with https:// prefix)"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where Fluentd runs"
  type        = string
  default     = "logging"
}

variable "service_account_name" {
  description = "Kubernetes service account name for Fluentd"
  type        = string
  default     = "fluentd"
}

variable "log_retention_days" {
  description = "S3 object expiry in days. 30 days is the deliberate cost guard for dev — logs beyond this window are unlikely to be needed and EBS cost is already covered by Elasticsearch."
  type        = number
  default     = 30
}
