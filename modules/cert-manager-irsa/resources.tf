data "aws_caller_identity" "current" {}

resource "aws_iam_role" "cert_manager" {
  name = "cert-manager-irsa-${var.cluster_name}"

  tags = {
    component = "platform-tools"
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

resource "aws_iam_policy" "cert_manager" {
  name        = "cert-manager-policy-${var.cluster_name}"
  description = "Allows cert-manager to solve DNS-01 ACME challenges via Route53"

  tags = {
    component = "platform-tools"
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetChange"
        Effect = "Allow"
        Action = ["route53:GetChange"]
        # GetChange is global — change IDs are not zone-scoped
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Sid      = "UpsertDNSChallenge"
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets"]
        Resource = "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
      },
      {
        Sid      = "ListZones"
        Effect   = "Allow"
        Action   = ["route53:ListHostedZonesByName"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  role       = aws_iam_role.cert_manager.name
  policy_arn = aws_iam_policy.cert_manager.arn
}
