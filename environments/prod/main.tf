/**
 * # Production Environment
 *
 * Full HA: Multi-AZ, WAF, KMS encryption, flow logs, warm pool.
 */

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws"; version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "chinzorig-terraform-state"
    key            = "production-infra/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "web-platform"
      Environment = "prod"
      ManagedBy   = "Terraform"
      Owner       = "chinzorig"
    }
  }
}

module "vpc" {
  source               = "../../modules/vpc"
  project_name         = "web-platform"
  environment          = "prod"
  vpc_cidr             = "10.1.0.0/16"           # Different CIDR from dev
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]
  single_nat_gateway   = false                     # HA: NAT per AZ
  enable_flow_logs     = true                      # Audit all traffic
  flow_log_retention_days = 90
}

module "alb" {
  source            = "../../modules/loadbalancer"
  project_name      = "web-platform"
  environment       = "prod"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  enable_waf        = true                         # WAF enabled
  waf_rate_limit    = 2000
}

module "compute" {
  source                 = "../../modules/compute"
  project_name           = "web-platform"
  environment            = "prod"
  vpc_id                 = module.vpc.vpc_id
  public_subnets         = module.vpc.public_subnet_ids
  instance_type          = "t3.small"              # Larger instance
  min_size               = 2                        # Min 2 for HA
  max_size               = 6
  desired_size           = 2
  cpu_target_value       = 65                       # Tighter threshold
  alb_security_group_ids = [module.alb.security_group_id]
  target_group_arns      = [module.alb.target_group_arn]
  secrets_arn            = module.database.secret_arn
  enable_warm_pool       = true                     # Pre-warmed instances
}

module "database" {
  source                     = "../../modules/database"
  project_name               = "web-platform"
  environment                = "prod"
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.compute.security_group_id]
  db_username                = var.db_username
  db_password                = var.db_password
  instance_class             = "db.t3.medium"       # Larger DB
  multi_az                   = true                  # HA: standby replica
  create_kms_key             = true                  # Custom KMS key
  backup_retention_days      = 30                    # Longer retention
}

module "monitoring" {
  source          = "../../modules/monitoring"
  project_name    = "web-platform"
  environment     = "prod"
  asg_name        = module.compute.asg_name
  rds_instance_id = "web-platform-prod"
  alb_arn_suffix  = module.alb.alb_arn_suffix
  alert_email     = var.alert_email
  cpu_threshold   = 70                               # Tighter threshold
}

variable "db_username" { type = string; sensitive = true }
variable "db_password" { type = string; sensitive = true }
variable "alert_email" { type = string; default = "chinzorig11222@gmail.com" }

output "alb_url" { value = "http://${module.alb.alb_dns_name}" }
