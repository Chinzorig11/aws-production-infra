variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "allowed_security_group_ids" { type = list(string) }
variable "db_name" { type = string; default = "appdb" }
variable "db_username" { type = string; sensitive = true }
variable "db_password" { type = string; sensitive = true }
variable "instance_class" { type = string; default = "db.t3.micro" }
variable "engine_version" { type = string; default = "15.4" }
variable "allocated_storage" { type = number; default = 20 }
variable "max_allocated_storage" { type = number; default = 100 }
variable "multi_az" { type = bool; default = false }
variable "backup_retention_days" { type = number; default = 7 }
variable "create_kms_key" { type = bool; default = false }
variable "slow_query_threshold_ms" { type = string; default = "1000" }
