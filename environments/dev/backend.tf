terraform {
  backend "s3" {
    bucket         = "chinzorig-terraform-state"
    key            = "production-infra/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
