# ──────────────────────────────────────────
# Random password for RDS master user
# Stored in AWS Secrets Manager
# ──────────────────────────────────────────
resource "random_password" "db_master_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?" # excludes chars that break conn strings
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.environment}/capital-call/db-credentials"
  description             = "RDS master credentials for capital call database"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master_password.result
    host     = module.rds.db_endpoint
    port     = 5432
    dbname   = var.db_name
  })
}

# ──────────────────────────────────────────
# Networking module
# ──────────────────────────────────────────
module "networking" {
  source = "./modules/networking"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}

# ──────────────────────────────────────────
# RDS module
# ──────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  environment              = var.environment
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  db_name                  = var.db_name
  db_username              = var.db_username
  db_password              = random_password.db_master_password.result
  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage
  db_engine_version        = var.db_engine_version
  db_backup_retention_days = var.db_backup_retention_days
  db_deletion_protection   = var.db_deletion_protection
  db_multi_az              = var.db_multi_az
  allowed_cidr_blocks      = var.allowed_cidr_blocks
}