# ---------------------------------------------------------------------------
# OIDC provider for GitHub Actions
# ---------------------------------------------------------------------------
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = var.tags
}

# ---------------------------------------------------------------------------
# CI role — assumable only by this repo's workflows running on allowed_ref.
# `push` and `workflow_dispatch` both produce sub=repo:<org>/<repo>:ref:<ref>,
# so one condition covers both triggers. Pull request runs get a different
# `sub` and cannot assume this role — by design, PRs only build (no push).
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:${var.allowed_ref}"]
    }
  }
}

resource "aws_iam_role" "ci" {
  name               = "${var.project}-github-actions-ci"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# ---------------------------------------------------------------------------
# Permissions — push/pull on this project's ECR repositories only.
# GetAuthorizationToken is account-wide by AWS design and does not support
# resource-level restriction; the rest is scoped to ecr_repository_arns.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_policy" "ecr_push" {
  name        = "${var.project}-github-actions-ecr-push"
  description = "Push/pull access to the project's ECR repositories for GitHub Actions CI."
  policy      = data.aws_iam_policy_document.ecr_push.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.ci.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

# ---------------------------------------------------------------------------
# ECS deploy permissions — only created when ecs_service_arns is provided.
# Scopes UpdateService/Describe to the specific services; RegisterTaskDefinition
# and DescribeTaskDefinition are account-wide (AWS does not support resource
# restrictions on those actions). PassRole is scoped to the task execution role.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_deploy" {
  count = length(var.ecs_service_arns) > 0 ? 1 : 0

  statement {
    sid    = "ECSServiceUpdate"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
    ]
    resources = concat(
      var.ecs_service_arns,
      ["arn:aws:ecs:*:*:task/*"],
    )
  }

  statement {
    sid    = "ECSTaskDefinition"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:ListTaskDefinitions",
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.ecs_task_execution_role_arn != "" ? [1] : []
    content {
      sid       = "PassExecutionRole"
      effect    = "Allow"
      actions   = ["iam:PassRole"]
      resources = [var.ecs_task_execution_role_arn]
    }
  }
}

resource "aws_iam_policy" "ecs_deploy" {
  count       = length(var.ecs_service_arns) > 0 ? 1 : 0
  name        = "${var.project}-github-actions-ecs-deploy"
  description = "ECS deploy access for GitHub Actions CI."
  policy      = data.aws_iam_policy_document.ecs_deploy[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_deploy" {
  count      = length(var.ecs_service_arns) > 0 ? 1 : 0
  role       = aws_iam_role.ci.name
  policy_arn = aws_iam_policy.ecs_deploy[0].arn
}

# ---------------------------------------------------------------------------
# EKS deploy permissions — only created when eks_cluster_arn is provided.
# DescribeCluster is required by `aws eks update-kubeconfig` and by the Helm
# provider. Scoped to the single cluster ARN; no account-wide wildcards needed.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "eks_deploy" {
  count = var.eks_cluster_arn != "" ? 1 : 0

  statement {
    sid    = "EKSDescribeCluster"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
    ]
    resources = [var.eks_cluster_arn]
  }
}

resource "aws_iam_policy" "eks_deploy" {
  count       = var.eks_cluster_arn != "" ? 1 : 0
  name        = "${var.project}-github-actions-eks-deploy"
  description = "EKS describe access for GitHub Actions CI (update-kubeconfig + Helm)."
  policy      = data.aws_iam_policy_document.eks_deploy[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_deploy" {
  count      = var.eks_cluster_arn != "" ? 1 : 0
  role       = aws_iam_role.ci.name
  policy_arn = aws_iam_policy.eks_deploy[0].arn
}
