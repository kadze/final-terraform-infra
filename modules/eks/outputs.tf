output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "oidc_issuer" {
  description = "OIDC issuer URL — used by Story 1.2/1.3/1.4 to create IRSA roles"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "node_role_arn" {
  value = aws_iam_role.nodes.arn
}

output "node_security_group_id" {
  value = aws_security_group.nodes.id
}
