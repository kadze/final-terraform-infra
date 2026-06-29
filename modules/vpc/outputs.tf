output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_ipv4_cidr" {
  value = aws_vpc.main.cidr_block
}

output "vpc_ipv6_cidr" {
  value = aws_vpc.main.ipv6_cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ipv6_cidrs" {
  value = aws_subnet.public[*].ipv6_cidr_block
}

output "private_subnet_ipv4_cidrs" {
  value = aws_subnet.private[*].cidr_block
}

output "private_subnet_ipv6_cidrs" {
  value = aws_subnet.private[*].ipv6_cidr_block
}

output "nat_gateway_public_ip" {
  description = "EIP of the NAT gateway (null when enable_nat64 = false)"
  value       = try(aws_eip.nat[0].public_ip, null)
}
