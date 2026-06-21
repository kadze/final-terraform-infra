module "vpc" {
  source = "../../../modules/vpc"

  vpc_cidr     = "10.25.0.0/16"
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

  # NAT64 + DNS64: one NAT gateway covers all IPv4-only AWS APIs and internet hosts.
  # Replaces the 5 interface VPC endpoints (ec2, ecr_api, ecr_dkr, sts, elbv2).
  enable_nat64 = true
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

module "alb_controller_irsa" {
  source = "../../../modules/alb-controller-irsa"

  cluster_name              = module.eks.cluster_name
  cluster_oidc_issuer_url   = module.eks.oidc_issuer
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
}

module "grafana_cloudwatch_irsa" {
  source = "../../../modules/grafana-cloudwatch-irsa"

  cluster_name              = module.eks.cluster_name
  cluster_oidc_issuer_url   = module.eks.oidc_issuer
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
}

module "cert_manager_irsa" {
  source = "../../../modules/cert-manager-irsa"

  cluster_name              = module.eks.cluster_name
  cluster_oidc_issuer_url   = module.eks.oidc_issuer
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  hosted_zone_id            = var.hosted_zone_id
}

module "external_dns_irsa" {
  source = "../../../modules/external-dns-irsa"

  cluster_name              = module.eks.cluster_name
  cluster_oidc_issuer_url   = module.eks.oidc_issuer
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  hosted_zone_id            = var.hosted_zone_id
}

module "secrets_csi_irsa_versus" {
  source = "../../../modules/secrets-csi-irsa"

  cluster_name              = module.eks.cluster_name
  cluster_oidc_issuer_url   = module.eks.oidc_issuer
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  app_name                  = "versus"
  namespace                 = "versus"
  service_account_name      = "versus"
  secret_path_prefix        = "versus/"
}

module "secrets_csi_irsa_proshop" {
  source = "../../../modules/secrets-csi-irsa"

  cluster_name              = module.eks.cluster_name
  cluster_oidc_issuer_url   = module.eks.oidc_issuer
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  app_name                  = "proshop"
  namespace                 = "proshop"
  service_account_name      = "proshop"
  secret_path_prefix        = "proshop/"
}

module "secrets_csi_irsa_weather" {
  source = "../../../modules/secrets-csi-irsa"

  cluster_name              = module.eks.cluster_name
  cluster_oidc_issuer_url   = module.eks.oidc_issuer
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  app_name                  = "weather"
  namespace                 = "weather"
  service_account_name      = "weather"
  secret_path_prefix        = "weather/"
}

# SharedGHATerraformRole is managed by Story 1.2 — we only attach an inline policy
# so the platform-tools GHA workflow can read SSM params and update Route53 DNS.
# Route53 upsert is used instead of external-dns (Story 1.5 will replace this).
resource "aws_iam_role_policy" "shared_gha_platform_tools" {
  name = "platform-tools-ops-${var.environment}"
  role = "SharedGHATerraformRole"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SSMGrafanaParams"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:us-east-1:381492277294:parameter/eks-kadze-${var.environment}/*"
      },
      {
        Sid    = "Route53GrafanaDNS"
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets",
        ]
        Resource = "*"
      }
    ]
  })
}
