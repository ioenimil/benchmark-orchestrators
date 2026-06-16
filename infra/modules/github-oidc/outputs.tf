output "role_arn" {
  description = "IAM role ARN GitHub Actions assumes via OIDC. Set this as the AWS_ROLE_ARN repository secret."
  value       = aws_iam_role.ci.arn
}
