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

  backend "s3" {
    # bucket and key are injected at init time via -backend-config in CI:
    #   bucket = "${AWS_ACCOUNT_ID}-state-bucket-dev"
    #   key    = "${GITHUB_REF_NAME}.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
