variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used for subnet auto-discovery tags by the ALB controller"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "azs" {
  description = "Availability zones to deploy subnets into (exactly 3 required)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "IPv4 CIDRs for the 3 public (dual-stack, LB-only) subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "IPv4 CIDRs for the 3 private (IPv6-primary, nodes-only) subnets"
  type        = list(string)
}

variable "enable_nat64" {
  description = "Provision a NAT gateway + DNS64 so IPv6-only nodes can reach IPv4-only AWS APIs and internet hosts without per-service interface endpoints"
  type        = bool
  default     = false
}
