variable "project_name" { type = string }
variable "environment" { type = string }
variable "region" { type = string; default = "us-east-1" }
variable "asg_name" { type = string }
variable "rds_instance_id" { type = string; default = "" }
variable "alb_arn_suffix" { type = string; default = "" }
variable "alert_email" { type = string; default = "" }
variable "cpu_threshold" { type = number; default = 80 }
variable "rds_storage_threshold_bytes" { type = number; default = 5368709120 }
variable "alb_5xx_threshold" { type = number; default = 10 }
variable "latency_threshold_seconds" { type = number; default = 3 }
variable "kms_key_id" { type = string; default = "" }
