variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version. Verify 'one behind latest' on deploy day via aws eks describe-addon-versions."
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  description = "VPC ID from the vpc module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes and control plane ENIs"
  type        = list(string)
}

variable "admin_role_arns" {
  description = "IAM role ARNs granted cluster-admin via EKS access entries (GHA role + any human roles)"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "asg_min_size" {
  type    = number
  default = 1
}

variable "asg_max_size" {
  type    = number
  default = 3
}

variable "asg_desired_size" {
  type    = number
  default = 1
}
