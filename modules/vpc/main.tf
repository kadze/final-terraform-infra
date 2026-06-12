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

# EIGW — IPv6-only outbound for private subnets. No NAT, no public IPv4.
# This is where the per-node IPv4 charge dies.
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

# Private subnets — IPv6-primary, nodes only.
# ipv6_native = true: instances get IPv6 addresses only, no public IPv4.
resource "aws_subnet" "private" {
  count = 3

  vpc_id            = aws_vpc.main.id
  ipv6_cidr_block   = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index + 3)
  availability_zone = var.azs[count.index]

  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = true
  ipv6_native                     = true

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

# Private route table — EIGW for IPv6 egress only. No IPv4 default route (no NAT).
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
