terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.31.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "tfstate-reservas-${data.aws_caller_identity.current.account_id}"
  lock_table  = "tfstate-reservas-lock"
  tags = {
    Projeto = "api-reservas"
    Origem  = "terraform"
    Dono    = "prova-devops"
  }
}

# Bucket criado via AWS CLI: o Learner Lab bloqueia a leitura de Object Lock
# que o recurso aws_s3_bucket faz, então o recurso nativo não funciona aqui.
resource "terraform_data" "state_bucket" {
  input = local.bucket_name

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      B=${local.bucket_name}
      if ! aws s3api head-bucket --bucket "$B" 2>/dev/null; then
        aws s3api create-bucket --bucket "$B" --region us-east-1
      fi
      aws s3api put-bucket-versioning --bucket "$B" --versioning-configuration Status=Enabled
      aws s3api put-bucket-encryption --bucket "$B" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
      aws s3api put-public-access-block --bucket "$B" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
      aws s3api put-bucket-tagging --bucket "$B" --tagging 'TagSet=[{Key=Projeto,Value=api-reservas},{Key=Origem,Value=terraform},{Key=Dono,Value=prova-devops}]'
    EOT
  }
}

resource "aws_dynamodb_table" "lock" {
  name         = local.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  tags         = local.tags

  attribute {
    name = "LockID"
    type = "S"
  }
}