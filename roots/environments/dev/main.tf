# DO NOT REMOVE DUMMY MODULE references and their code, they should remain as examples
locals {
  # EKS cluster built by Story 1.1 — fill in from cluster OIDC endpoint once known
  cluster_name              = "ubuntu-dev-cluster"
  cluster_oidc_issuer_url   = "https://oidc.eks.us-east-1.amazonaws.com/id/179BA38F58C87CBEB547703AE6E09E62"                                 #TODO (this code is different in different clusters)
  cluster_oidc_provider_arn = "arn:aws:iam::383585068161:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/179BA38F58C87CBEB547703AE6E09E62" #TODO -||-
}

# ELBv2 interface endpoint — ALB controller pods are on IPv6-only nodes with no NAT.
# Without this, CreateLoadBalancer/DescribeLoadBalancers calls hit the public IPv4
# endpoint and hang indefinitely. Story 1.1 added EC2/ECR/STS endpoints; this one
# was missed and is needed for Story 1.3 Gateway API provisioning.
resource "aws_vpc_endpoint" "elbv2" {
  vpc_id              = "vpc-029dc342a8deff9eb"
  service_name        = "com.amazonaws.us-east-1.elasticloadbalancing"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = ["subnet-0f8a5338046f52c43", "subnet-0cc6cd5fa8c456023", "subnet-0453b7aee9200d984"]
  security_group_ids  = ["sg-0a9cb0a8447451f53"]
  private_dns_enabled = true

  tags = {
    component = "platform-tools"
  }
}

module "alb_controller_irsa" {
  source = "../../../modules/alb-controller-irsa"

  cluster_name              = local.cluster_name
  cluster_oidc_issuer_url   = local.cluster_oidc_issuer_url
  cluster_oidc_provider_arn = local.cluster_oidc_provider_arn
}
