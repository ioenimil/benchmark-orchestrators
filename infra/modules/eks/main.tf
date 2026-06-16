terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

data "aws_partition" "current" {}

locals {
  cluster_name = "${var.project}-eks"
  # control-plane ENIs span all subnets; nodes only run in private subnets.
  cluster_subnet_ids = concat(var.private_subnet_ids, var.public_subnet_ids)
}

# ---------------------------------------------------------------------------
# Cluster IAM role
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.cluster_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.k8s_version

  vpc_config {
    subnet_ids              = local.cluster_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# ---------------------------------------------------------------------------
# OIDC provider (mandatory for IRSA)
# ---------------------------------------------------------------------------
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Node group IAM role
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${local.cluster_name}-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "AmazonEKSWorkerNodePolicy",
    "AmazonEKS_CNI_Policy",
    "AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

# ---------------------------------------------------------------------------
# Managed node group (AL2023, private subnets)
# ---------------------------------------------------------------------------
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.cluster_name}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids
  ami_type        = var.node_ami_type
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.node]
}

# Allow the public ALB SG to reach pods directly (target-type ip). The LB
# Controller also auto-manages a backend SG at runtime; this rule is explicit
# per the architecture spec.
resource "aws_vpc_security_group_ingress_rule" "alb_to_nodes" {
  security_group_id            = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description                  = "ALB to frontend pods"
  referenced_security_group_id = var.alb_sg_id
  from_port                    = var.frontend_port
  to_port                      = var.frontend_port
  ip_protocol                  = "tcp"
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller — IRSA role
# ---------------------------------------------------------------------------
# Fetch the official IAM policy at plan time (kept in lockstep with the chart).
data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc" {
  name        = "${local.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  description = "Permissions for the AWS Load Balancer Controller"
  policy      = data.http.lbc_iam_policy.response_body

  tags = var.tags
}

locals {
  oidc_provider_url = replace(aws_iam_openid_connect_provider.this.url, "https://", "")
}

data "aws_iam_policy_document" "lbc_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name               = "${local.cluster_name}-lbc-irsa"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# ---------------------------------------------------------------------------
# Gateway API CRDs (standard channel) — MUST exist before the LBC starts its
# Gateway reconciler and before any Gateway/HTTPRoute is applied.
# ---------------------------------------------------------------------------
resource "null_resource" "gateway_api_crds" {
  triggers = {
    cluster         = aws_eks_cluster.this.name
    gateway_version = var.gateway_api_version
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      PROFILE_ARG=""
      if [ -n "${var.aws_profile}" ]; then PROFILE_ARG="--profile ${var.aws_profile}"; fi
      aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region ${var.region} $PROFILE_ARG
      kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml
    EOT
  }

  depends_on = [aws_eks_node_group.this]
}

# ---------------------------------------------------------------------------
# AWS Load Balancer Controller (Helm) with Gateway API support enabled
# ---------------------------------------------------------------------------
resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lbc_chart_version
  namespace  = "kube-system"
  wait       = true

  set {
    name  = "clusterName"
    value = aws_eks_cluster.this.name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lbc.arn
  }

  # Enable Gateway API reconciliation (chart >= 1.14 / controller >= 2.14).
  # Verify the exact key with `helm show values eks-charts/aws-load-balancer-controller`.
  set {
    name  = "enableGatewayAPI"
    value = "true"
  }

  depends_on = [
    aws_eks_node_group.this,
    aws_iam_role_policy_attachment.lbc,
    null_resource.gateway_api_crds,
  ]
}
