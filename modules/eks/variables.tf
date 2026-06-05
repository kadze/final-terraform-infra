variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of private subnets for EKS nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "IDs of public subnets for load balancers"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
}