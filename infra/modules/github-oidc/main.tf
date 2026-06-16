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
