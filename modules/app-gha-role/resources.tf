data "aws_caller_identity" "current" {}

resource "aws_iam_role" "app_gha" {
  name = "${var.app_name}-ubuntu-github-actions"

  tags = {
    component = "app-ci-cd"
    app       = var.app_name
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:environment:${var.github_environment}"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "app_gha" {
  name        = "${var.app_name}-ubuntu-github-actions-policy"
  description = "Allows ${var.app_name} GitHub Actions to push images to ECR and access EKS"

  tags = {
    component = "app-ci-cd"
    app       = var.app_name
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = var.ecr_repo_arns
      },
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:us-east-1:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_gha" {
  role       = aws_iam_role.app_gha.name
  policy_arn = aws_iam_policy.app_gha.arn
}

resource "aws_eks_access_entry" "app_gha" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.app_gha.arn
  type          = "STANDARD"

  tags = {
    component = "app-ci-cd"
    app       = var.app_name
  }
}

resource "aws_eks_access_policy_association" "app_gha" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.app_gha.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
