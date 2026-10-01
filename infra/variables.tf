variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "reservas"
}

variable "repo_url" {
  type    = string
  default = "https://github.com/pedrozk123/prova-primeiro-bimestre-devops.git"
}

variable "key_name" {
  type    = string
  default = "vockey"
}

variable "ssh_allowed_cidr" {
  description = "CIDR liberado para SSH. Ideal: seu IP com /32"
  type        = string
  default     = "0.0.0.0/0"
}

variable "db_name" {
  type    = string
  default = "reservas"
}

variable "db_username" {
  type    = string
  default = "reservas_user"
}

variable "db_password" {
  description = "Senha do RDS, passada por TF_VAR_db_password (nunca no código)"
  type        = string
  sensitive   = true
}