output "bucket_name" {
  value      = local.bucket_name
  depends_on = [terraform_data.state_bucket]
}

output "lock_table" {
  value = aws_dynamodb_table.lock.name
}