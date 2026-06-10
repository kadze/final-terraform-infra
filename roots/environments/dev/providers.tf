provider "aws" {
  region = "us-east-1"

  # team and environment are safe as provider defaults — they're the same for
  # every resource in this root. component differs per resource and is set inline.
  default_tags {
    tags = {
      team        = "ubuntu"
      environment = "dev"
    }
  }
}

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    region       = "us-east-1"
    use_lockfile = true
    # bucket and key are injected by the workflow:
    # -backend-config="bucket=${AWS_ACCOUNT_ID}-state-bucket-dev"
    # -backend-config="key=${GITHUB_REF#refs/heads/}.tfstate"
  }
}
