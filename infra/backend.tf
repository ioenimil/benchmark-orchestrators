# Remote state in S3 with NATIVE state locking (use_lockfile = true) — no
# DynamoDB lock table. Requires Terraform >= 1.10.
#
# Partial configuration: `bucket` and `region` are supplied at init time so no
# account ID is hardcoded in version control. The bootstrap project creates the
# bucket and `scripts/bootstrap.sh` writes a `backend.hcl` with the values:
#
#   terraform init -backend-config=backend.hcl
#
terraform {
  backend "s3" {
    key          = "shopnow/root/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
