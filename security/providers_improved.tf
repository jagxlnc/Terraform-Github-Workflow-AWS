terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}

# Provider for ACM certificate (CloudFront requires certificates in us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}