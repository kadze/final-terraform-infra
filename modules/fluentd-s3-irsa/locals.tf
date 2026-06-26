data "aws_caller_identity" "current" {}

locals {
  oidc_provider   = replace(var.cluster_oidc_issuer_url, "https://", "")
  log_bucket_name = "kadze-logs-${var.cluster_name}-${data.aws_caller_identity.current.account_id}"
}
