resource "aws_ecr_repository" "this" {
  for_each = var.repo_names

  name = each.value

  # force_delete lets `terraform destroy` remove the repo even if it still
  # holds images (fine for a benchmark/sandbox).
  force_delete         = true
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Name = each.value })
}
