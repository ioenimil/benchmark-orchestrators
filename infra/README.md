# ShopNow Infrastructure

Modular Terraform that provisions the shared platform and deploys the **same
images** to **ECS Fargate** and **EKS (Gateway API)** for a benchmark comparison.

## Layout

```
infra/
├── bootstrap/          # run ONCE, local state -> creates the S3 remote-state bucket
├── modules/
│   ├── networking/     # VPC, 2-AZ subnets, 1 NAT, tiered SGs, LBC subnet tags
│   ├── ecr/            # frontend + backend repos
│   ├── rds/            # shared Postgres 16 (single-AZ)
│   ├── ecs/            # Fargate cluster, Cloud Map, ALB, services
│   └── eks/            # EKS 1.33 (AL2023), OIDC/IRSA, LB Controller + Gateway API CRDs
├── main.tf             # composition root: wires modules
├── providers.tf        # aws ~> 6.0, helm ~> 2.0 (exec auth), tls/http/null/random
├── backend.tf          # S3 backend, NATIVE locking (use_lockfile=true), NO DynamoDB
└── terraform.tfvars.example
```

## Remote state — native S3 locking (no DynamoDB)

State locking uses S3's native conditional-write lock (`use_lockfile = true`,
Terraform >= 1.10). The bootstrap project creates only a versioned + encrypted,
public-access-blocked bucket — there is **no DynamoDB lock table**.

## Order of operations

```bash
# 0. Auth (defaults assume profile nsp-sandbox, region eu-west-1)
export AWS_PROFILE=nsp-sandbox

# 1. Create the state bucket + generate infra/backend.hcl
scripts/bootstrap.sh

# 2. Provision everything
terraform -chdir=infra init -backend-config=backend.hcl
terraform -chdir=infra apply              # optionally -var image_tag=<sha>

# 3. Build + push images, then redeploy ECS with the real tag
scripts/build-push.sh <tag>
terraform -chdir=infra apply -var image_tag=<tag>

# 4. Deploy to EKS (CRDs, Helm release: configmap/secret/deployments/Gateway ALB)
scripts/eks-setup.sh <tag>

# 5. Get the URLs
terraform -chdir=infra output -raw ecs_alb_url
kubectl get gateway -n shopnow shopnow-gateway -o jsonpath='{.status.addresses[0].value}'

# 6. Always tear down after a session (correct order: Helm release first, then TF)
scripts/teardown.sh
```

## Notes / deviations

- **Backend port:** the EKS `backend` Service listens on **8000** (not 80) so it
  matches `BACKEND_PORT=8000` in the ConfigMap and the frontend nginx template
  (`proxy_pass http://${BACKEND_HOST}:${BACKEND_PORT}/`). Same port everywhere.
- **DATABASE_URL** uses the `postgresql+psycopg://` scheme the app's SQLAlchemy
  engine expects (psycopg v3), composed in `locals.tf` from the RDS module.
- **Gateway API:** ALB scheme is set to `internet-facing` via a
  `LoadBalancerConfiguration` referenced from the Gateway's
  `infrastructure.parametersRef`. Verify exact CRD fields against the LBC 2.14
  Gateway docs before applying.
