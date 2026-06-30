variable "vpc_id" {
  type        = string
  description = "VPC ID where the RDS instance will be placed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet IPv4 CIDRs — only these can reach MySQL on port 3306"
}

variable "private_subnet_ipv6_cidrs" {
  type        = list(string)
  description = "Private subnet IPv6 CIDRs — pods are IPv6-only so need direct MySQL access over IPv6"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name — used in resource naming"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. 'dev')"
}

variable "app_name" {
  type        = string
  description = "App name (e.g. 'versus') — used in resource naming and tags"
}

variable "db_name" {
  type        = string
  description = "Name of the database to create inside the RDS instance"
}

variable "db_username" {
  type        = string
  description = "Master username for the RDS instance"
}
