variable "name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "instance_profile" {
  type    = string
  default = "LabInstanceProfile"
}

variable "key_name" {
  description = "Key pair existente no Lab (vockey). Use null para não ter SSH."
  type        = string
  default     = "vockey"
}

variable "repo_url" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}