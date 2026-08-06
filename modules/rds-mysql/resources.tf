resource "aws_db_subnet_group" "main" {
  name       = "${var.app_name}-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = {
    component = "database"
    app       = var.app_name
  }
}

resource "aws_security_group" "rds" {
  name   = "${var.app_name}-rds-${var.environment}"
  vpc_id = var.vpc_id

  tags = {
    component = "database"
    app       = var.app_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql" {
  for_each = toset(var.private_subnet_cidrs)

  security_group_id = aws_security_group.rds.id
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
  cidr_ipv4         = each.value

  tags = {
    component = "database"
    app       = var.app_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql_ipv6" {
  for_each = { for idx, cidr in var.private_subnet_ipv6_cidrs : tostring(idx) => cidr }

  security_group_id = aws_security_group.rds.id
  ip_protocol       = "tcp"
  from_port         = 3306
  to_port           = 3306
  cidr_ipv6         = each.value

  tags = {
    component = "database"
    app       = var.app_name
  }
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.rds.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    component = "database"
    app       = var.app_name
  }
}

resource "aws_db_instance" "main" {
  identifier = "${var.app_name}-${var.environment}"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  # Dual-stack gives the instance both IPv4 and IPv6 endpoints.
  # Required because EKS pods are IPv6-primary and MySQL 5.7 is IPv4-only on RDS.
  network_type = "DUAL"

  db_name  = var.db_name
  username = var.db_username

  # RDS manages the master password in Secrets Manager — no password in Terraform state.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false
  deletion_protection = false

  # Feature branches are destroyed on PR merge — no final snapshot needed.
  skip_final_snapshot = true

  tags = {
    component = "database"
    app       = var.app_name
  }
}
