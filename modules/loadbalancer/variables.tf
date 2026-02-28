variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "app_port" { type = number; default = 3000 }
variable "health_check_path" { type = string; default = "/health" }
variable "access_log_bucket" { type = string; default = "" }
variable "enable_stickiness" { type = bool; default = false }
variable "enable_waf" { type = bool; default = false }
variable "waf_rate_limit" { type = number; default = 2000 }
