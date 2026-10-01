data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

locals {
  user_data = <<-EOT
    #!/bin/bash
    set -x
    dnf install -y docker git
    systemctl enable --now docker
    git clone ${var.repo_url} /opt/reservas
    cd /opt/reservas/app
    docker build -t api-reservas:1.0 .
    docker run -d --restart unless-stopped --name api -p 3000:3000 \
      -e DB_HOST=${var.db_host} \
      -e DB_PORT=${var.db_port} \
      -e DB_USER=${var.db_user} \
      -e DB_PASSWORD='${var.db_password}' \
      -e DB_NAME=${var.db_name} \
      -e DB_SSL=true \
      api-reservas:1.0
  EOT
}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = var.instance_profile
  key_name                    = var.key_name
  user_data                   = local.user_data
  user_data_replace_on_change = true

  tags = merge(var.tags, { Name = "${var.name}-api" })
}