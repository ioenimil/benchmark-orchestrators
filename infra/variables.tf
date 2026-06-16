variable "project" {
  description = "Project name, used as a prefix across resources."
  type        = string
  default     = "shopnow"
}

variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "Named AWS profile to authenticate with. Empty string falls back to the default credential chain."
  type        = string
  default     = "nsp-sandbox"
}

variable "environment" {
  description = "Deployment environment name (used in tags)."
  type        = string
  default     = "benchmark"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones."
  type        = number
  default     = 2
}

# ---- Database ----
variable "db_name" {
  description = "Initial Postgres database name."
  type        = string
  default     = "orchestrator"
}

variable "db_username" {
  description = "Postgres master username."
  type        = string
  default     = "shopnow"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_engine_version" {
  description = "Postgres engine version."
  type        = string
  default     = "16.4"
}

# ---- Images ----
variable "image_tag" {
  description = "Image tag deployed to ECS (and patched into k8s). Pass a real tag / git SHA — never rely on :latest."
  type        = string
  default     = "latest"
}

variable "ecr_repo_names" {
  description = "ECR repositories to create."
  type        = set(string)
  default     = ["shopnow-frontend", "shopnow-backend"]
}

# ---- CI/CD ----
variable "github_repository" {
  description = "GitHub \"org/repo\" allowed to assume the CI role via OIDC (must match the repo running the GitHub Actions workflows)."
  type        = string
  default     = "ioenimil/benchmark-orchestrators"
}

# ---- EKS ----
variable "k8s_version" {
  description = "Kubernetes version (1.33+ -> AL2023 AMIs)."
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = "EKS node instance type."
  type        = string
  default     = "t3.medium"
}

variable "lbc_chart_version" {
  description = "aws-load-balancer-controller Helm chart version (>= 1.14.0 for Gateway API L7)."
  type        = string
  default     = "1.14.0"
}

variable "gateway_api_version" {
  description = "Gateway API CRD release (standard channel), e.g. v1.5.0."
  type        = string
  default     = "v1.5.0"
}
