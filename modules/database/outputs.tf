output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.this.endpoint
  sensitive   = true
}
output "secret_arn" {
  description = "Secrets Manager ARN"
  value       = aws_secretsmanager_secret.db.arn
}
output "security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}
output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}
