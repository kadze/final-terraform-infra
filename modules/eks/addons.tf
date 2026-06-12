# Add-ons are applied after the cluster and node group are ready.
# Versions omitted intentionally — Terraform will use the default version for
# the cluster's Kubernetes version. Pin them once you've verified the cluster.

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  # IPv6 mode is inferred automatically from the cluster's ip_family setting.
  # No explicit configuration_values needed for basic IPv6 operation.

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_autoscaling_group.nodes, aws_eks_access_entry.nodes]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_autoscaling_group.nodes, aws_eks_access_entry.nodes]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_autoscaling_group.nodes, aws_eks_access_entry.nodes]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"

  # Using node-role permissions for now. Story 1.2 will introduce IRSA
  # and set service_account_role_arn here instead.

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_autoscaling_group.nodes, aws_eks_access_entry.nodes]
}
