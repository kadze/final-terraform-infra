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

# Private route table — EIGW for native IPv6; NAT64 route added inline when enable_nat64=true.
# Must use inline route blocks (not separate aws_route resources) — Terraform treats inline
# routes as authoritative and would delete any separately managed routes on the same table.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.main.id
  }

  dynamic "route" {
    for_each = var.enable_nat64 ? [1] : []
    content {
      # Well-Known Prefix: DNS64 synthesises IPv4-only addresses here so IPv6-only
      # nodes can reach them via the NAT gateway (NAT64 translation).
      ipv6_cidr_block = "64:ff9b::/96"
      nat_gateway_id  = aws_nat_gateway.main[0].id
    }
  }

  tags = {
    Name        = "${local.name}-private-rt"
    Environment = var.environment
  }
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

# S3 — free gateway endpoint; kept even with NAT64 (no hourly cost, avoids NAT data charge for S3)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { Name = "${local.name}-s3" }
}

