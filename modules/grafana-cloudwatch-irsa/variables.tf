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
  description = "Kubernetes namespace where Grafana runs"
  type        = string
  default     = "monitoring"
}

variable "service_account_name" {
  description = "Kubernetes service account name for Grafana"
  type        = string
  default     = "grafana"
}
