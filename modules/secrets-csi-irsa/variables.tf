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

variable "app_name" {
  description = "Application name — used in the IAM role name and to scope secret access"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the app runs"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes service account name for the app pod"
  type        = string
}

variable "secret_path_prefix" {
  description = "Secrets Manager secret name prefix this app is allowed to read (e.g. 'myapp/')"
  type        = string
}
