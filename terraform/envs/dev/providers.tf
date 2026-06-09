terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Recommended for real projects:
  # backend "s3" {
  #   bucket         = "croptrace-terraform-state"
  #   key            = "dev/eks/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   dynamodb_table = "croptrace-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}
