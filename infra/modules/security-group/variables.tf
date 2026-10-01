variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR liberado para SSH (22). Ideal: seu IP, ex.: 200.1.2.3/32"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  type    = map(string)
  default = {}
}