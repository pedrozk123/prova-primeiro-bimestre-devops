terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
  }

  # Backend não aceita variáveis, por isso os valores são fixos
  backend "s3" {
    bucket         = "tfstate-reservas-436760226340"
    key            = "api-reservas/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-reservas-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}