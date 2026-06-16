variable "aws_region" {
  description = "AWS region for the remote-state bucket. Must match the region used by the root module backend."
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "Named AWS CLI/SDK profile used to authenticate. Set to null to fall back to the default credential chain (env vars, instance role, etc.)."
  type        = string
  default     = "nsp-sandbox"
}

variable "project" {
  description = "Project name, used as a prefix for the state bucket and in tags."
  type        = string
  default     = "shopnow"
}
