variable "repo_names" {
  description = "Set of ECR repository names to create."
  type        = set(string)
}

variable "project" {
  description = "Project name (used in tags)."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all repositories."
  type        = map(string)
  default     = {}
}
