resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, { Name = "${var.project}-db-subnet-group" })
}

resource "aws_db_instance" "this" {
  identifier     = "${var.project}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  port     = 5432

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  multi_az               = false
  publicly_accessible    = false

  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  tags = merge(var.tags, { Name = "${var.project}-postgres" })
}
