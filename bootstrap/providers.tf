provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local state — bootstrap is a one-time local apply with SSO creds.
  # The S3 state bucket must already exist (created manually before running this).
}
