locals {
  tags = {
    Project     = var.project
    ManagedBy   = "terraform"
    Environment = var.environment
  }

  # Static cluster name — computed from var.project so the networking module can
  # tag subnets for the LB Controller before the EKS cluster itself exists.
  eks_cluster_name = "${var.project}-eks"

}
