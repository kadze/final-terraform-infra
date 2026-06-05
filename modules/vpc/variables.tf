variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}