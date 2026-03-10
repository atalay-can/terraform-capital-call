output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "db_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "db_name" {
  description = "Database name"
  value       = var.db_name
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_instance_id" {
  description = "RDS instance identifier"
  value       = module.rds.db_instance_id
}