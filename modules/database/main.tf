/**
 * # Database Module
 *
 * RDS PostgreSQL with Secrets Manager integration,
 * automated backups, encryption, and performance insights.
 */

# --- Senior: Secrets Manager for credentials (not tfvars!) ---
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project_name}/${var.environment}/db-credentials"
  description             = "RDS credentials for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Name = "${var.project_name}-db-secret-${var.environment}"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = 5432
    dbname   = var.db_name
  })

  depends_on = [aws_db_instance.this]
}

# --- KMS Key for encryption ---
resource "aws_kms_key" "db" {
  count                   = var.create_kms_key ? 1 : 0
  description             = "KMS key for ${var.project_name} RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true  # Senior: automatic key rotation

  tags = {
    Name = "${var.project_name}-db-kms-${var.environment}"
  }
}

resource "aws_kms_alias" "db" {
  count         = var.create_kms_key ? 1 : 0
  name          = "alias/${var.project_name}-db-${var.environment}"
  target_key_id = aws_kms_key.db[0].key_id
}

# --- Security Group ---
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  description = "RDS PostgreSQL access"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  tags = {
    Name = "${var.project_name}-rds-sg-${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- DB Subnet Group ---
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-${var.environment}"
  }
}

# --- RDS Parameter Group (Senior: tuned for workload) ---
resource "aws_db_parameter_group" "this" {
  family = "postgres15"
  name   = "${var.project_name}-pg15-${var.environment}"

  parameter {
    name  = "log_min_duration_statement"
    value = var.slow_query_threshold_ms
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "pg_stat_statements.track"
    value = "all"
  }

  tags = {
    Name = "${var.project_name}-pg-params-${var.environment}"
  }
}

# --- RDS Instance ---
resource "aws_db_instance" "this" {
  identifier     = "${var.project_name}-${var.environment}"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.create_kms_key ? aws_kms_key.db[0].arn : null

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az            = var.multi_az
  publicly_accessible = false
  skip_final_snapshot = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-final-${formatdate("YYYY-MM-DD", timestamp())}" : null

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled          = true
  performance_insights_retention_period = var.environment == "prod" ? 731 : 7

  # Senior: Enhanced monitoring
  monitoring_interval = var.environment == "prod" ? 30 : 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Senior: Deletion protection for prod
  deletion_protection = var.environment == "prod"

  tags = {
    Name = "${var.project_name}-db-${var.environment}"
  }
}

# --- Enhanced Monitoring Role ---
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
