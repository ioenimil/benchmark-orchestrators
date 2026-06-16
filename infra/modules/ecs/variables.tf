variable "project" {
  description = "Project name (used in resource names)."
  type        = string
}

variable "region" {
  description = "AWS region (needed for the awslogs log driver)."
  type        = string
}

variable "vpc_id" {
  description = "VPC the cluster runs in."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the internet-facing ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for Fargate tasks."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group for the ALB."
  type        = string
}

variable "frontend_sg_id" {
  description = "Security group for frontend tasks."
  type        = string
}

variable "backend_sg_id" {
  description = "Security group for backend tasks."
  type        = string
}

variable "redis_sg_id" {
  description = "Security group for the redis task."
  type        = string
}

variable "frontend_image" {
  description = "Fully qualified frontend image (repo:tag)."
  type        = string
}

variable "backend_image" {
  description = "Fully qualified backend image (repo:tag)."
  type        = string
}

variable "redis_image" {
  description = "Redis image."
  type        = string
  default     = "redis:7-alpine"
}

variable "db_host" {
  description = "RDS endpoint hostname."
  type        = string
}

variable "db_port" {
  description = "RDS port."
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Postgres database name."
  type        = string
}

variable "db_user" {
  description = "Postgres master username."
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager secret ARN holding the RDS master credentials (managed by RDS)."
  type        = string
}

variable "namespace_name" {
  description = "Cloud Map private DNS namespace (service discovery domain)."
  type        = string
  default     = "shopnow.local"
}

variable "backend_host" {
  description = "Hostname the frontend uses to reach the backend (Cloud Map FQDN)."
  type        = string
  default     = "backend.shopnow.local"
}

variable "backend_port" {
  description = "Backend container port."
  type        = number
  default     = 8000
}

variable "redis_host" {
  description = "Hostname the backend uses to reach redis (Cloud Map FQDN)."
  type        = string
  default     = "redis.shopnow.local"
}

variable "redis_port" {
  description = "Redis port."
  type        = number
  default     = 6379
}

variable "frontend_port" {
  description = "Frontend (nginx) container port."
  type        = number
  default     = 80
}

variable "frontend_desired_count" {
  description = "Desired number of frontend tasks."
  type        = number
  default     = 2
}

variable "backend_desired_count" {
  description = "Desired number of backend tasks."
  type        = number
  default     = 2
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory (MiB)."
  type        = string
  default     = "512"
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
