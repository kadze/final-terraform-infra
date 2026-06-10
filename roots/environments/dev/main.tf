module "vpc" {
  source = "../../../modules/vpc"

  vpc_cidr    = "10.25.0.0/16"
  cluster_name = var.cluster_name
  environment  = var.environment

  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

  public_subnet_cidrs = [
    "10.25.0.0/19",
    "10.25.32.0/19",
    "10.25.64.0/19",
  ]

  private_subnet_cidrs = [
    "10.25.128.0/19",
    "10.25.160.0/19",
    "10.25.192.0/19",
  ]
}

module "eks" {
  source = "../../../modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = "1.35"
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  admin_role_arns    = var.admin_role_arns
}
