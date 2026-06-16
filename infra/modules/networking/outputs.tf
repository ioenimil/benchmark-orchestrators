output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALBs, NAT)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (ECS tasks, EKS nodes, RDS)."
  value       = aws_subnet.private[*].id
}

output "alb_sg_id" {
  description = "Security group for the public ALB."
  value       = aws_security_group.alb.id
}

output "frontend_sg_id" {
  description = "Security group for frontend (nginx) tasks."
  value       = aws_security_group.frontend.id
}

output "backend_sg_id" {
  description = "Security group for backend (FastAPI) tasks."
  value       = aws_security_group.backend.id
}

output "redis_sg_id" {
  description = "Security group for the Redis cache."
  value       = aws_security_group.redis.id
}

output "rds_sg_id" {
  description = "Security group for RDS Postgres."
  value       = aws_security_group.rds.id
}
