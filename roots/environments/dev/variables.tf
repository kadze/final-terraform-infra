variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "admin_role_arns" {
  description = "IAM role ARNs granted cluster-admin. Must include the GHA bootstrap role ARN (from bootstrap output) and any personal admin role."
  type        = list(string)
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for the team domain (shevtsov.click)"
  type        = string
}
