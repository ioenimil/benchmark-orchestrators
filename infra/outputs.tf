output "ecs_alb_url" {
  description = "Public URL of the ECS (Fargate) deployment."
  value       = "http://${module.ecs.alb_dns_name}"
}

output "ecs_cluster_name" {
  description = "ECS cluster name. Set as the ECS_CLUSTER_NAME Actions variable."
  value       = module.ecs.cluster_name
}

output "eks_cluster_name" {
  description = "EKS cluster name (for `aws eks update-kubeconfig`)."
  value       = module.eks.cluster_name
}

output "eks_url_hint" {
  description = "How to read the EKS public URL (the ALB is created by the Gateway resource, outside Terraform state)."
  value       = "kubectl get gateway -n shopnow shopnow-gateway -o jsonpath='{.status.addresses[0].value}'"
}

output "rds_endpoint" {
  description = "RDS Postgres endpoint (shared by both clusters)."
  value       = module.rds.endpoint
}

output "ecr_urls" {
  description = "Map of ECR repository name -> URL."
  value       = module.ecr.repository_urls
}

output "db_secret_arn" {
  description = "Secrets Manager secret ARN holding the RDS master credentials. The pipeline reads this to inject DB connection info into EKS."
  value       = module.rds.secret_arn
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC. Set as the AWS_ROLE_ARN repository secret."
  value       = module.github_oidc.role_arn
}

output "region" {
  description = "AWS region."
  value       = var.region
}
