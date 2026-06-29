variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "app_name" {
  type        = string
  description = "App name (e.g. 'versus')"
}

variable "github_org" {
  type        = string
  description = "GitHub organization"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (e.g. 'kadze-versus')"
}

variable "github_environment" {
  type        = string
  description = "GitHub Actions environment name (e.g. 'dev')"
}

variable "github_oidc_provider_arn" {
  type        = string
  description = "ARN of the GitHub Actions OIDC provider in this account"
}

variable "ecr_repo_arns" {
  type        = list(string)
  description = "ARNs of ECR repositories the workflow is allowed to push to"
}
