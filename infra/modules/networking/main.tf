data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Subnet tags required by the AWS Load Balancer Controller for subnet
  # autodiscovery. The cluster tag value "shared" lets multiple consumers use
  # the same subnets.
  cluster_shared_tag = { "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared" }
}

# ---------------------------------------------------------------------------
# VPC + Internet Gateway
# ---------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.project}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.project}-igw" })
}

# ---------------------------------------------------------------------------
# Public subnets (ALBs + NAT live here)
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    local.cluster_shared_tag,
    {
      Name                     = "${var.project}-public-${local.azs[count.index]}"
      "kubernetes.io/role/elb" = "1"
      Tier                     = "public"
    },
  )
}

# ---------------------------------------------------------------------------
# Private subnets (ECS tasks, EKS nodes, RDS)
# ---------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(
    var.tags,
    local.cluster_shared_tag,
    {
      Name                              = "${var.project}-private-${local.azs[count.index]}"
      "kubernetes.io/role/internal-elb" = "1"
      Tier                              = "private"
    },
  )
}

# ---------------------------------------------------------------------------
# Single NAT Gateway (cost) in the first public subnet
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.project}-nat-eip" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, { Name = "${var.project}-nat" })

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------------------
# Route tables
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.project}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.project}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---------------------------------------------------------------------------
# Security groups — tiered, least privilege. No inline rules (v6 pattern):
# all ingress/egress are separate aws_vpc_security_group_*_rule resources.
# ---------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Public ALB: allow HTTP from the internet."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.project}-alb-sg" })
}

resource "aws_security_group" "frontend" {
  name        = "${var.project}-frontend-sg"
  description = "Frontend (nginx) tasks: HTTP only from the ALB."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.project}-frontend-sg" })
}

resource "aws_security_group" "backend" {
  name        = "${var.project}-backend-sg"
  description = "Backend (FastAPI) tasks: only from the frontend."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.project}-backend-sg" })
}

resource "aws_security_group" "redis" {
  name        = "${var.project}-redis-sg"
  description = "Redis cache: only from the backend."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.project}-redis-sg" })
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "RDS Postgres: only from the backend."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.project}-rds-sg" })
}

# ---- Ingress rules (tiered) ------------------------------------------------
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.frontend_port
  to_port           = var.frontend_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "frontend_from_alb" {
  security_group_id            = aws_security_group.frontend.id
  description                  = "HTTP from the ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.frontend_port
  to_port                      = var.frontend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "backend_from_frontend" {
  security_group_id            = aws_security_group.backend.id
  description                  = "App traffic from the frontend"
  referenced_security_group_id = aws_security_group.frontend.id
  from_port                    = var.backend_port
  to_port                      = var.backend_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_backend" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Redis from the backend"
  referenced_security_group_id = aws_security_group.backend.id
  from_port                    = var.redis_port
  to_port                      = var.redis_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_backend" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Postgres from the backend"
  referenced_security_group_id = aws_security_group.backend.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}

# ---- Egress: all SGs allow all outbound (ECR pulls leave via NAT) ----------
resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = {
    alb      = aws_security_group.alb.id
    frontend = aws_security_group.frontend.id
    backend  = aws_security_group.backend.id
    redis    = aws_security_group.redis.id
    rds      = aws_security_group.rds.id
  }

  security_group_id = each.value
  description       = "Allow all outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
