locals {
  name = "${var.environment}-vpc"
}

resource "aws_vpc" "main" {
  cidr_block                       = var.vpc_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = {
    Name        = local.name
    Environment = var.environment
  }
}

# IGW — handles IPv4 + IPv6 traffic for the public subnets
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${local.name}-igw"
    Environment = var.environment
  }
}

# EIP + NAT gateway — created only when enable_nat64 = true.
# NAT64/DNS64 lets IPv6-only nodes reach any IPv4-only host via the
# 64:ff9b::/96 Well-Known Prefix without per-service interface endpoints.
resource "aws_eip" "nat" {
  count  = var.enable_nat64 ? 1 : 0
  domain = "vpc"
  tags = {
    Name        = "${local.name}-nat"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat64 ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]
  tags = {
    Name        = "${local.name}-nat"
    Environment = var.environment
  }
}

# EIGW — IPv6-only outbound for private subnets (native IPv6 / dual-stack destinations).
resource "aws_egress_only_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${local.name}-eigw"
    Environment = var.environment
  }
}

# Public subnets — dual-stack, LB-only.
# ALBs land here; worker nodes do not.
resource "aws_subnet" "public" {
  count = 3

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  ipv6_cidr_block   = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index)
  availability_zone = var.azs[count.index]

  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = true
  ipv6_native                     = false

  tags = {
    Name                                        = "${local.name}-public-${count.index + 1}"
    Environment                                 = var.environment
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Private subnets — dual-stack, nodes only.
# No public IPv4 on launch; IPv6 assigned so pods get IPv6 addresses (EKS ip_family=ipv6).
resource "aws_subnet" "private" {
  count = 3

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  ipv6_cidr_block   = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index + 3)
  availability_zone = var.azs[count.index]

  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = true
  # DNS64 synthesizes AAAA in 64:ff9b::/96 for IPv4-only hostnames so IPv6-only
  # nodes can reach them via the NAT gateway (when enable_nat64 = true).
  enable_dns64 = var.enable_nat64

  tags = {
    Name                                        = "${local.name}-private-${count.index + 1}"
    Environment                                 = var.environment
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Public route table — IGW for both IPv4 and IPv6
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${local.name}-public-rt"
    Environment = var.environment
  }
}

# Private route table — EIGW for native IPv6 egress; NAT64 route added when enable_nat64=true.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.main.id
  }

  tags = {
    Name        = "${local.name}-private-rt"
    Environment = var.environment
  }
}

# NAT64 route — sends the Well-Known Prefix (IPv4-mapped IPv6) to the NAT gateway.
# DNS64 on the private subnets synthesizes AAAA in this prefix for IPv4-only hostnames.
resource "aws_route" "private_nat64" {
  count                       = var.enable_nat64 ? 1 : 0
  route_table_id              = aws_route_table.private.id
  destination_ipv6_cidr_block = "64:ff9b::/96"
  nat_gateway_id              = aws_nat_gateway.main[0].id
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Shared SG for interface endpoints — HTTPS from within the VPC only
resource "aws_security_group" "endpoints" {
  name        = "${local.name}-endpoints"
  description = "HTTPS ingress from VPC to interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name        = "${local.name}-endpoints"
    Environment = var.environment
  }
}

# EC2 — nodeadm calls DescribeInstances during bootstrap; no IPv6 public endpoint
resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${local.name}-ec2" }
}

# ECR — addon image pulls (api + dkr pair required)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${local.name}-ecr-api" }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${local.name}-ecr-dkr" }
}

# S3 — ECR image layers are stored in S3; gateway endpoint has no hourly cost
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { Name = "${local.name}-s3" }
}

# STS — IRSA token exchange (AssumeRoleWithWebIdentity); no IPv6 public endpoint
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${local.name}-sts" }
}

# ELBv2 — ALB controller calls CreateLoadBalancer/DescribeLoadBalancers; no IPv6 public endpoint
resource "aws_vpc_endpoint" "elbv2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.elasticloadbalancing"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${local.name}-elbv2" }
}
