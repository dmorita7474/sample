
#------------------------------------------------------------------------------
# Database Credentials using Secrets Manager
#------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "aurora_master_password" {
  name_prefix = "aurora-master-password-"
}

resource "aws_secretsmanager_secret_version" "aurora_master_password_version" {
  secret_id     = aws_secretsmanager_secret.aurora_master_password.id
  secret_string = jsonencode({
    username = "postgresadmin",
    password = "ThisIsAPlaceholderPasswordChangeMe"
  })
  lifecycle {
    ignore_changes = [secret_string]
  }
}

#------------------------------------------------------------------------------
# Database Network & Security
#------------------------------------------------------------------------------

# Subnet group for the RDS cluster
resource "aws_db_subnet_group" "aurora" {
  name       = "aurora-serverless-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# Security group for the Aurora cluster
resource "aws_security_group" "aurora_sg" {
  name        = "aurora-serverless-sg"
  description = "Allow traffic to Aurora from FastAPI service"
  vpc_id      = module.vpc.vpc_id

  # Allow inbound traffic from the FastAPI service
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.fastapi_sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#------------------------------------------------------------------------------
# Aurora Serverless v2 Cluster
#------------------------------------------------------------------------------

resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "aurora-serverless-cluster"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned" # Serverless v2 is a capacity configuration within provisioned mode
  engine_version          = "15.5"
  database_name           = "sampledb"
  master_username         = jsondecode(aws_secretsmanager_secret_version.aurora_master_password_version.secret_string)["username"]
  master_password         = jsondecode(aws_secretsmanager_secret_version.aurora_master_password_version.secret_string)["password"]
  db_subnet_group_name    = aws_db_subnet_group.aurora.name
  vpc_security_group_ids  = [aws_security_group.aurora_sg.id]
  skip_final_snapshot     = true

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2
  }
}

resource "aws_rds_cluster_instance" "aurora" {
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
}
