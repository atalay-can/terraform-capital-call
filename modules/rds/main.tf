# ──────────────────────────────────────────
# DB Subnet Group (RDS must span 2+ AZs)
# ──────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name        = "capital-call-subnet-group-${var.environment}"
  subnet_ids  = var.private_subnet_ids
  description = "Private subnets for capital call RDS"

  tags = { Name = "capital-call-subnet-group-${var.environment}" }
}

# ──────────────────────────────────────────
# Security Group for RDS
# ──────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "capital-call-rds-sg-${var.environment}"
  description = "Controls access to the capital call RDS instance"
  vpc_id      = var.vpc_id

  # Allow PostgreSQL from specified CIDRs (VPN, bastion, app servers)
  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      description = "PostgreSQL from allowed CIDRs"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  # Allow PostgreSQL from within the VPC (app servers in private subnet)
  ingress {
    description = "PostgreSQL from within VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "capital-call-rds-sg-${var.environment}" }
}

# ──────────────────────────────────────────
# RDS Parameter Group (PostgreSQL tuning)
# ──────────────────────────────────────────
resource "aws_db_parameter_group" "main" {
  name        = "capital-call-pg-${var.environment}"
  family      = "postgres15"
  description = "Custom parameter group for capital call DB"

  # Enable UUID generation extension support
  parameter {
    name  = "rds.force_ssl"
    value = "1" # enforce TLS connections
  }

  tags = { Name = "capital-call-pg-${var.environment}" }
}

# ──────────────────────────────────────────
# RDS Instance
# ──────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier = "capital-call-${var.environment}"

  # Engine
  engine               = "postgres"
  engine_version       = var.db_engine_version
  parameter_group_name = aws_db_parameter_group.main.name

  # Compute & Storage
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage # enables autoscaling
  storage_type            = "gp3"
  storage_encrypted       = true # always encrypt at rest

  # Database
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # never expose RDS directly to internet

  # Availability
  multi_az = var.db_multi_az

  # Backups
  backup_retention_period   = var.db_backup_retention_days
  backup_window             = "03:00-04:00" # UTC
  maintenance_window        = "mon:04:00-mon:05:00"
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "capital-call-prod-final-snapshot" : null

  # Protection
  deletion_protection = var.db_deletion_protection

  # Enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = { Name = "capital-call-rds-${var.environment}" }
}

# ──────────────────────────────────────────
# IAM Role for Enhanced Monitoring
# ──────────────────────────────────────────
resource "aws_iam_role" "rds_monitoring" {
  name = "capital-call-rds-monitoring-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}