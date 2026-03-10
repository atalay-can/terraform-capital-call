# ──────────────────────────────────────────
# Global
# ──────────────────────────────────────────
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-central-1" # Frankfurt — close to bunch's Berlin HQ
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

# ──────────────────────────────────────────
# Networking
# ──────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to deploy subnets into (minimum 2 for RDS subnet group)"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (RDS lives here)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (bastion / NAT lives here)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

# ──────────────────────────────────────────
# RDS
# ──────────────────────────────────────────
variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "capital_call_db"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "db_admin"
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro" # cheapest for dev; use db.t3.medium+ for prod
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.15"
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable deletion protection on RDS (set true for prod)"
  type        = bool
  default     = false
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for high availability"
  type        = bool
  default     = false # set true for prod
}

variable "allowed_cidr_blocks" {
  description = "CIDRs allowed to connect to RDS (e.g., your office IP, VPN CIDR)"
  type        = list(string)
  default     = [] # locked down by default — add your IP/VPN CIDR
}