variable "region" { type = string; default = "us-east-1" }
variable "project_name" { type = string; default = "web-platform" }
variable "vpc_cidr" { type = string; default = "10.0.0.0/16" }
variable "public_subnet_cidrs" { type = list(string); default = ["10.0.1.0/24", "10.0.2.0/24"] }
variable "private_subnet_cidrs" { type = list(string); default = ["10.0.3.0/24", "10.0.4.0/24"] }
variable "db_username" { type = string; sensitive = true }
variable "db_password" { type = string; sensitive = true }
variable "alert_email" { type = string; default = "chinzorig11222@gmail.com" }
