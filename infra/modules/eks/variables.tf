variable "project" {
  description = "Project name (used in resource names)."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "aws_profile" {
  description = "AWS profile for the local-exec kubectl/aws calls used to install Gateway API CRDs. Empty string uses the default credential chain."
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC the cluster runs in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for nodes (and control-plane ENIs)."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets (control-plane ENIs + LBC ALB autodiscovery)."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ALB security group allowed to reach node pods (target-type ip)."
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version. 1.33+ requires AL2023 AMIs."
  type        = string
  default     = "1.33"
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired node count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
  default     = 4
}

variable "node_ami_type" {
  description = "AMI type for nodes. Must be AL2023 on k8s 1.33+ (AL2 is unsupported)."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "frontend_port" {
  description = "Pod port the ALB targets reach (frontend nginx)."
  type        = number
  default     = 80
}

variable "lbc_chart_version" {
  description = "Helm chart version for aws-load-balancer-controller. Chart >= 1.14.0 ships controller app >= 2.14.0, which is required for Gateway API L7/ALB support."
  type        = string
  default     = "1.14.0"
}

variable "gateway_api_version" {
  description = "Gateway API CRD release (standard channel). Pin an exact v1.5.x patch; the LBC 2.14.0 is built against Gateway API v1.5.0."
  type        = string
  default     = "v1.5.0"
}

variable "db_secret_arn" {
  description = "ARN of the RDS-managed master credentials secret that the External Secrets Operator may read."
  type        = string
}

variable "eso_chart_version" {
  description = "Helm chart version for external-secrets (External Secrets Operator). Chart 2.x serves the external-secrets.io/v1 API (v1beta1 was removed in ESO v0.17). Verify with `helm search repo external-secrets/external-secrets --versions`."
  type        = string
  default     = "2.6.0"
}

variable "reloader_chart_version" {
  description = "Helm chart version for stakater/reloader. Verify available versions with `helm search repo stakater/reloader --versions`."
  type        = string
  default     = "2.2.12"
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
