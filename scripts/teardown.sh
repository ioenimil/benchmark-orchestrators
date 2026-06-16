#!/usr/bin/env bash
# Tear everything down in the correct order. The EKS ALB is created by the LB
# Controller and lives OUTSIDE Terraform state — it must be deleted (by removing
# the Gateway) BEFORE `terraform destroy`, or it orphans and blocks VPC teardown.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
INFRA_DIR="$REPO_ROOT/infra"

AWS_PROFILE="${AWS_PROFILE:-nsp-sandbox}"
export AWS_PROFILE

echo ">> Uninstalling the shopnow Helm release (removes the Gateway -> ALB)"
helm uninstall shopnow -n shopnow || true

echo ">> Deleting the shopnow namespace"
kubectl delete namespace shopnow --ignore-not-found=true || true

echo ">> Waiting ~60s for the LB Controller to delete the ALB"
sleep 60

echo ">> terraform destroy"
terraform -chdir="$INFRA_DIR" destroy -auto-approve

echo ">> Done. To also remove the remote-state bucket:"
echo "   terraform -chdir=infra/bootstrap destroy -auto-approve"
