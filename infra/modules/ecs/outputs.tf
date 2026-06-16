output "alb_dns_name" {
  description = "Public DNS name of the ECS ALB."
  value       = aws_lb.this.dns_name
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_names" {
  description = "Names of the ECS services."
  value = {
    frontend = aws_ecs_service.frontend.name
    backend  = aws_ecs_service.backend.name
    redis    = aws_ecs_service.redis.name
  }
}

output "namespace_name" {
  description = "Cloud Map private DNS namespace."
  value       = aws_service_discovery_private_dns_namespace.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "service_arns" {
  description = "ARNs of the ECS services."
  value = {
    frontend = aws_ecs_service.frontend.id
    backend  = aws_ecs_service.backend.id
    redis    = aws_ecs_service.redis.id
  }
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role."
  value       = aws_iam_role.execution.arn
}
