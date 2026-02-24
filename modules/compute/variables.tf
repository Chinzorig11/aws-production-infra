variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "public_subnets" { type = list(string) }
variable "instance_type" { type = string; default = "t3.micro" }
variable "app_port" { type = number; default = 3000 }
variable "root_volume_size" { type = number; default = 20 }
variable "min_size" { type = number; default = 1 }
variable "max_size" { type = number; default = 3 }
variable "desired_size" { type = number; default = 1 }
variable "cpu_target_value" { type = number; default = 70 }
variable "enable_request_scaling" { type = bool; default = false }
variable "request_target_value" { type = number; default = 1000 }
variable "alb_resource_label" { type = string; default = "" }
variable "alb_security_group_ids" { type = list(string); default = [] }
variable "target_group_arns" { type = list(string); default = [] }
variable "log_bucket_arn" { type = string; default = "" }
variable "secrets_arn" { type = string; default = "" }
variable "enable_warm_pool" { type = bool; default = false }
