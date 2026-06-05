# DO NOT REMOVE DUMMY MODULE references and their code, they should remain as examples
locals {
  greeting = "Hi"

  # EKS cluster built by Story 1.1 — fill in from cluster OIDC endpoint once known
  cluster_name              = "temporary-eks-cluster-dev"
  cluster_oidc_issuer_url   = "https://oidc.eks.us-east-1.amazonaws.com/id/CLUSTER_OIDC_ID_DEV"
  cluster_oidc_provider_arn = "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/CLUSTER_OIDC_ID_DEV"
}

module "module1" {
  source   = "../../../dummy-module-1"
  greeting = local.greeting
}

module "module2" {
  source             = "../../../dummy-module-2"
  input_from_module1 = module.module1.greeting_message
}

module "alb_controller_irsa" {
  source = "../../../modules/alb-controller-irsa"

  cluster_name              = local.cluster_name
  cluster_oidc_issuer_url   = local.cluster_oidc_issuer_url
  cluster_oidc_provider_arn = local.cluster_oidc_provider_arn
}
