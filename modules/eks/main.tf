# ── Security group for worker nodes ──────────────────────────────────────────

resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes"
  description = "Worker node security group"
  vpc_id      = var.vpc_id

  # Node-to-node (required for pod-to-pod traffic)
  ingress {
    description = "node-to-node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # All outbound IPv4 (needed for API server calls via public endpoint)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound IPv6 (primary egress path — via EIGW)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name      = "${var.cluster_name}-nodes"
    component = "platform-tools"
  }
}

# Allow control plane → nodes after the cluster exists (resolves circular dependency)
resource "aws_security_group_rule" "cluster_to_nodes" {
  description              = "control-plane to nodes"
  security_group_id        = aws_security_group.nodes.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# ── EKS cluster ───────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.nodes.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  kubernetes_network_config {
    ip_family = "ipv6"
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  tags = {
    Name      = var.cluster_name
    component = "shared"
  }
}

# ── EKS access entries ────────────────────────────────────────────────────────

# Node role — EC2_LINUX type handles node join without aws-auth ConfigMap
resource "aws_eks_access_entry" "nodes" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.nodes.arn
  type          = "EC2_LINUX"
}

# Human/CI admin roles (GHA bootstrap role + any personal admin role)
resource "aws_eks_access_entry" "admins" {
  for_each = toset(var.admin_role_arns)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = toset(var.admin_role_arns)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
