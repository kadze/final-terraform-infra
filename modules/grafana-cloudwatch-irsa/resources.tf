resource "aws_iam_role" "grafana_cloudwatch" {
  name = "grafana-cloudwatch-irsa-${var.cluster_name}"

  tags = {
    component = "monitoring"
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

resource "aws_iam_policy" "grafana_cloudwatch" {
  name        = "grafana-cloudwatch-policy-${var.cluster_name}"
  description = "Allows Grafana to read CloudWatch metrics and tags for dashboards"

  tags = {
    component = "monitoring"
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
        ]
        Resource = "*"
      },
      {
        Sid    = "TagsForDimensionFilters"
        Effect = "Allow"
        Action = [
          "tag:GetResources",
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2AndELBDescribeForAnnotations"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana_cloudwatch.name
  policy_arn = aws_iam_policy.grafana_cloudwatch.arn
}
