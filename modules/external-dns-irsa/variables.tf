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
  description = "Kubernetes namespace where external-dns runs"
  type        = string
  default     = "external-dns"
}

variable "service_account_name" {
  description = "Kubernetes service account name for external-dns"
  type        = string
  default     = "external-dns"
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID external-dns is allowed to manage records in"
  type        = string
}
