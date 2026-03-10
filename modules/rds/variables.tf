variable "environment"              { type = string }
variable "vpc_id"                   { type = string }
variable "private_subnet_ids"       { type = list(string) }
variable "db_name"                  { type = string }

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_instance_class"        { type = string }
variable "db_allocated_storage"     { type = number }
variable "db_max_allocated_storage" { type = number }
variable "db_engine_version"        { type = string }
variable "db_backup_retention_days" { type = number }
variable "db_deletion_protection"   { type = bool }
variable "db_multi_az"              { type = bool }
variable "allowed_cidr_blocks"      { type = list(string) }