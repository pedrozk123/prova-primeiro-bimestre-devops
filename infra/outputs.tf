output "ec2_public_ip" {
  value = module.ec2.public_ip
}

output "api_url" {
  value = "http://${module.ec2.public_ip}:3000"
}

output "rds_endpoint" {
  value = module.rds.address
}

output "vpc_id" {
  value = module.vpc.vpc_id
}