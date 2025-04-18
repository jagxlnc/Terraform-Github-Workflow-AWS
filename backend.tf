# This file configures the Terraform backend for state storage
# Uncomment and configure for your environment

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "static-website/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }
