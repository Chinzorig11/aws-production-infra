/**
 * # Dev Environment
 *
 * Development environment using all infrastructure modules.
 * Cost-optimized: single NAT, no WAF, smaller instances.
 */

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "dev"
      ManagedBy   = "Terraform"
      Owner       = "chinzorig"
    }
  }
}

# --- Network ---
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = "dev"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = true  # Cost savings: 1 NAT instead of 2
  enable_flow_logs     = false # Disabled for dev
}

# --- Load Balancer ---
module "alb" {
  source = "../../modules/loadbalancer"

  project_name      = var.project_name
  environment       = "dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_port          = 3000
  enable_waf        = false # No WAF for dev
}

# --- Compute ---
module "compute" {
  source = "../../modules/compute"

  project_name           = var.project_name
  environment            = "dev"
  vpc_id                 = module.vpc.vpc_id
  public_subnets         = module.vpc.public_subnet_ids
  instance_type          = "t3.micro"
  min_size               = 1
  max_size               = 2
  desired_size           = 1
  alb_security_group_ids = [module.alb.security_group_id]
  target_group_arns      = [module.alb.target_group_arn]
  secrets_arn            = module.database.secret_arn
  enable_warm_pool       = false # No warm pool for dev
}

# --- Database ---
module "database" {
  source = "../../modules/database"

  project_name               = var.project_name
  environment                = "dev"
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.compute.security_group_id]
  db_username                = var.db_username
  db_password                = var.db_password
  instance_class             = "db.t3.micro"
  multi_az                   = false # Single AZ for dev
  create_kms_key             = false # Default encryption for dev
  backup_retention_days      = 1
}

# --- Monitoring ---
module "monitoring" {
  source = "../../modules/monitoring"

  project_name    = var.project_name
  environment     = "dev"
  region          = var.region
  asg_name        = module.compute.asg_name
  rds_instance_id = "${var.project_name}-dev"
  alb_arn_suffix  = module.alb.alb_arn_suffix
  alert_email     = var.alert_email
}

# --- Outputs ---
output "alb_url" {
  value = "http://${module.alb.alb_dns_name}"
}

output "dashboard_url" {
  value = module.monitoring.dashboard_url
}
