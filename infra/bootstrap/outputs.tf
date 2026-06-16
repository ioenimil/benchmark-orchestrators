output "state_bucket_name" {
  description = "Name of the S3 bucket that stores the root module's remote state. Plug this into infra/backend.tf (or backend.hcl)."
  value       = aws_s3_bucket.state.id
}

output "aws_region" {
  description = "Region the state bucket lives in. The root backend must use the same region."
  value       = var.aws_region
}

output "backend_config_hint" {
  description = "Ready-to-use S3 backend block for the root module (native locking, no DynamoDB)."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.state.id}"
        key          = "shopnow/root/terraform.tfstate"
        region       = "${var.aws_region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
