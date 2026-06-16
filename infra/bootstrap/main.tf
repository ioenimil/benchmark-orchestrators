terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  # Globally unique, deterministic name derived from account + region.
  # No account IDs are hardcoded — they are resolved at apply time.
  state_bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
    Component = "tf-remote-state"
  }
}

# ---------------------------------------------------------------------------
# Remote state bucket — versioned + encrypted, all public access blocked.
# State LOCKING is handled natively by S3 (use_lockfile = true in the root
# backend config), so NO DynamoDB lock table is created here.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  # Allow `terraform destroy` of the bootstrap to remove the bucket even if it
  # still holds (versioned) state objects. Safe for a benchmark/sandbox setup.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
