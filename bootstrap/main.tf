locals {
  github_org  = "312school"
  github_repo = "kadze-terraform-infra-25c-ubuntu"
  environment = "dev"
  oidc_host   = "token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://${local.oidc_host}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "OIDC-provider-for-GitHub-Actions"
    Description = "it tells your AWS account to trust JWTs issued by GitHub Actions"
  }
}

resource "aws_iam_role" "gha_terraform" {
  name        = "gha-terraform-bootstrap-dev"
  description = "Ad-hoc GHA Terraform role for Story 1.1. Story 1.2 will consolidate."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
          "${local.oidc_host}:sub" = "repo:${local.github_org}/${local.github_repo}:environment:${local.environment}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "gha_terraform" {
  name   = "gha-terraform-bootstrap-policy"
  role   = aws_iam_role.gha_terraform.id
  policy = file("${path.module}/gha-terraform-policy.json")
}
