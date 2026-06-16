variable "project" {
  description = "Project name (used in resource naming)."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI role, in \"org/repo\" form."
  type        = string
}

variable "allowed_ref" {
  description = "Git ref allowed to assume the CI role. `push` and `workflow_dispatch` from this ref both produce a matching `sub` claim."
  type        = string
  default     = "refs/heads/main"
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the CI role may push/pull images to."
  type        = list(string)
}

variable "ecs_service_arns" {
  description = "ARNs of the ECS services the CI role may update and describe."
  type        = list(string)
  default     = []
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role the CI role must be able to pass to ECS."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
