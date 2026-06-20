data "aws_caller_identity" "current" {}

resource "aws_iam_role" "secrets_csi_app" {
  name = "secrets-csi-${var.app_name}-irsa-${var.cluster_name}"

  tags = {
    component = "platform-tools"
    app       = var.app_name
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${local.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "secrets_csi_app" {
  name        = "secrets-csi-${var.app_name}-policy-${var.cluster_name}"
  description = "Allows ${var.app_name} pods to read secrets from Secrets Manager via the CSI driver"

  tags = {
    component = "platform-tools"
    app       = var.app_name
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:${var.secret_path_prefix}*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_csi_app" {
  role       = aws_iam_role.secrets_csi_app.name
  policy_arn = aws_iam_policy.secrets_csi_app.arn
}
