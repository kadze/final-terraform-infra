# DO NOT REMOVE DUMMY MODULE references and their code, they should remain as examples
locals {
  # EKS cluster built by Story 1.1 — fill in from cluster OIDC endpoint once known
  cluster_name              = "ubuntu-dev-cluster"
  cluster_oidc_issuer_url   = "https://oidc.eks.us-east-1.amazonaws.com/id/287337B7769634D2DD2BA62AD053165D" #TODO (this code is different in different clusters)
  cluster_oidc_provider_arn = "arn:aws:iam::383585068161:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/287337B7769634D2DD2BA62AD053165D" #TODO -||-
}

module "alb_controller_irsa" {
  source = "../../../modules/alb-controller-irsa"

  cluster_name              = local.cluster_name
  cluster_oidc_issuer_url   = local.cluster_oidc_issuer_url
  cluster_oidc_provider_arn = local.cluster_oidc_provider_arn
}
