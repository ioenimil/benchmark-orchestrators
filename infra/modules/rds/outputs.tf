output "endpoint" {
  description = "Connection endpoint host (no port)."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port Postgres listens on."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.this.db_name
}

output "username" {
  description = "Master username."
  value       = aws_db_instance.this.username
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret that holds the RDS master credentials."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
