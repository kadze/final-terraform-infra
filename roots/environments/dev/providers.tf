terraform {
  required_version = ">= 1.10"

  backend "s3" {
    region       = "us-east-1"
    bucket       = "383585068161-state-bucket-dev"
    key          = "environments/dev/terraform.tfstate"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      team        = "ubuntu"
      environment = "dev"
    }
  }
}