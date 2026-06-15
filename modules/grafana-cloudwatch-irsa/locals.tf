locals {
  oidc_provider = replace(var.cluster_oidc_issuer_url, "https://", "")
}
