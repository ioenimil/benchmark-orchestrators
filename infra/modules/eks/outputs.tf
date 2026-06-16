output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "lbc_role_arn" {
  description = "IRSA role ARN used by the AWS Load Balancer Controller."
  value       = aws_iam_role.lbc.arn
}

output "node_security_group_id" {
  description = "Cluster security group attached to nodes."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
