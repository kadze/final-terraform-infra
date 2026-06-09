provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      team        = "ubuntu"
      environment = "staging"
    }
  }
}

terraform {
  required_version = ">= 1.10"

  backend "s3" {
    # bucket and key are injected at init time via -backend-config in CI:
    #   bucket = "${AWS_ACCOUNT_ID}-state-bucket-staging"
    #   key    = "${GITHUB_REF_NAME}.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
