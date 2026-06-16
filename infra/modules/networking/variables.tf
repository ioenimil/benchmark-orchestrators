variable "project" {
  description = "Project name, used in resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across."
  type        = number
  default     = 2
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster. Used for the kubernetes.io/cluster/<name> subnet tags the AWS Load Balancer Controller needs for subnet autodiscovery."
  type        = string
}

variable "frontend_port" {
  description = "Container/listener port the frontend (nginx) serves on."
  type        = number
  default     = 80
}

variable "backend_port" {
  description = "Container port the backend (FastAPI) listens on."
  type        = number
  default     = 8000
}

variable "redis_port" {
  description = "Port Redis listens on."
  type        = number
  default     = 6379
}

variable "rds_port" {
  description = "Port Postgres listens on."
  type        = number
  default     = 5432
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
