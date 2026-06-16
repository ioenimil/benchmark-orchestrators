variable "project" {
  description = "Project name (used in resource names)."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "rds_sg_id" {
  description = "Security group ID controlling access to the DB instance."
  type        = string
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "orchestrator"
}

variable "db_username" {
  description = "Master username for the database."
  type        = string
  default     = "shopnow"
}

variable "engine_version" {
  description = "Postgres engine version (16.x)."
  type        = string
  default     = "16.10"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
