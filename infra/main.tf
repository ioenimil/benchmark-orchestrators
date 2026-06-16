module "networking" {
  source = "./modules/networking"

  project          = var.project
  vpc_cidr         = var.vpc_cidr
  az_count         = var.az_count
  eks_cluster_name = local.eks_cluster_name
  tags             = local.tags
}

module "ecr" {
  source = "./modules/ecr"

  repo_names = var.ecr_repo_names
  project    = var.project
  tags       = local.tags
}

module "github_oidc" {
  source = "./modules/github-oidc"

  project             = var.project
  github_repository   = var.github_repository
  ecr_repository_arns = values(module.ecr.repository_arns)
  tags                = local.tags
}

module "rds" {
  source = "./modules/rds"

  project            = var.project
  private_subnet_ids = module.networking.private_subnet_ids
  rds_sg_id          = module.networking.rds_sg_id
  db_name            = var.db_name
  db_username        = var.db_username
  instance_class     = var.db_instance_class
  engine_version     = var.db_engine_version
  tags               = local.tags
}

module "ecs" {
  source = "./modules/ecs"

  project            = var.project
  region             = var.region
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  alb_sg_id          = module.networking.alb_sg_id
  frontend_sg_id     = module.networking.frontend_sg_id
  backend_sg_id      = module.networking.backend_sg_id
  redis_sg_id        = module.networking.redis_sg_id

  frontend_image = "${module.ecr.repository_urls["shopnow-frontend"]}:${var.image_tag}"
  backend_image  = "${module.ecr.repository_urls["shopnow-backend"]}:${var.image_tag}"

  db_host       = module.rds.endpoint
  db_port       = module.rds.port
  db_name       = module.rds.db_name
  db_user       = module.rds.username
  db_secret_arn = module.rds.secret_arn

  tags = local.tags
}

module "eks" {
  source = "./modules/eks"

  project             = var.project
  region              = var.region
  aws_profile         = var.aws_profile
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids
  alb_sg_id           = module.networking.alb_sg_id
  k8s_version         = var.k8s_version
  node_instance_type  = var.node_instance_type
  lbc_chart_version   = var.lbc_chart_version
  gateway_api_version = var.gateway_api_version
  tags                = local.tags
}
