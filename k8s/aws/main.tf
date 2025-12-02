locals {
  frp_ingress_rules = var.enable_frp_access ? [
    {
      description = "FRP control port"
      port        = var.frp_server_port
      cidrs       = var.jump_host_port_7005_cidrs
    },
    {
      description = "FRP SSH tunnel"
      port        = var.frp_ssh_proxy_port
      cidrs       = var.jump_host_port_7006_cidrs
    }
  ] : []
  bootstrap_cidr_list = join(" ", var.jump_host_bootstrap_ssh_cidrs)
  bootstrap_cidr_hash = sha1(jsonencode(var.jump_host_bootstrap_ssh_cidrs))
}

resource "aws_instance" "jump_host" {
  ami                         = var.jump_host_ami
  instance_type               = var.jump_host_instance_type
  subnet_id                   = var.jump_host_subnet_id
  private_ip                  = var.jump_host_private_ip
  key_name                    = trimspace(var.jump_host_key_name) == "" ? null : var.jump_host_key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jump_host.id]
  monitoring                  = false
  ebs_optimized               = false

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              ADMIN="${var.jump_host_admin_user}"
              ADMIN_HOME=$(getent passwd ${var.jump_host_admin_user} | cut -d: -f6)
              mkdir -p "$${ADMIN_HOME}/.ssh"
              cat <<'KEY' > "$${ADMIN_HOME}/.ssh/authorized_keys"
              ${var.jump_host_admin_authorized_key}
              KEY
              chown -R "${var.jump_host_admin_user}:${var.jump_host_admin_user}" "$${ADMIN_HOME}/.ssh"
              chmod 700 "$${ADMIN_HOME}/.ssh"
              chmod 600 "$${ADMIN_HOME}/.ssh/authorized_keys"
              EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_size           = var.jump_host_root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = var.jump_host_root_volume_encrypted
    kms_key_id            = var.jump_host_root_volume_kms_key_id
    iops                  = var.jump_host_root_volume_iops
    throughput            = var.jump_host_root_volume_throughput
  }

  tags = var.jump_host_tags

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_security_group" "jump_host" {
  name        = var.jump_host_security_group_name
  description = var.jump_host_security_group_description
  vpc_id      = var.jump_host_vpc_id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.jump_host_ssh_cidrs
  }

  ingress {
    description = "WireGuard VPN"
    from_port   = var.wireguard_listen_port
    to_port     = var.wireguard_listen_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = local.frp_ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidrs
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.jump_host_security_group_tags

  lifecycle {
    prevent_destroy = true
  }

  revoke_rules_on_delete = true
}

resource "null_resource" "bootstrap_security_group" {
  triggers = {
    sg_id = aws_security_group.jump_host.id
    cidrs = local.bootstrap_cidr_hash
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if [ "${local.bootstrap_cidr_list}" = "" ]; then
        exit 0
      fi
      for CIDR in ${local.bootstrap_cidr_list}; do
        aws ec2 authorize-security-group-ingress \
          --group-id ${aws_security_group.jump_host.id} \
          --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$CIDR,Description='Bootstrap SSH'}]" >/dev/null 2>&1 || true
      done
    EOT
  }
}

resource "null_resource" "wireguard_server" {
  depends_on = [
    aws_instance.jump_host,
    aws_security_group.jump_host,
    aws_eip_association.jump_host,
    null_resource.bootstrap_security_group
  ]

  triggers = {
    instance_id         = aws_instance.jump_host.id
    wireguard_address     = var.wireguard_address
    wireguard_listen_port = var.wireguard_listen_port
    wireguard_peers_hash  = sha1(jsonencode(var.wireguard_peers))
    script_hash           = filesha1("${path.module}/scripts/wireguard-bootstrap.sh")
  }

  connection {
    host    = var.bastion_public_ip
    user    = var.jump_host_admin_user
    agent   = true
    timeout = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/wireguard-bootstrap.sh"
    destination = "/home/${var.jump_host_admin_user}/wireguard-bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/${var.jump_host_admin_user}/wireguard-bootstrap.sh",
      "sudo WG_ADDRESS='${var.wireguard_address}' WG_PORT='${var.wireguard_listen_port}' WG_SERVER_PRIVATE_KEY_B64='${base64encode(var.bastion_wireguard_private_key)}' WG_PEERS_B64='${base64encode(jsonencode(var.wireguard_peers))}' JUMP_USER='${var.jump_host_jump_user}' JUMP_USER_KEY_B64='${base64encode(var.jump_host_jump_user_public_key)}' /home/${var.jump_host_admin_user}/wireguard-bootstrap.sh"
    ]
  }
}

resource "null_resource" "lockdown_security_group" {
  depends_on = [
    null_resource.wireguard_server,
    null_resource.bootstrap_security_group
  ]

  triggers = {
    sg_id = aws_security_group.jump_host.id
    cidrs = local.bootstrap_cidr_hash
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if [ "${local.bootstrap_cidr_list}" = "" ]; then
        exit 0
      fi
      for CIDR in ${local.bootstrap_cidr_list}; do
        aws ec2 revoke-security-group-ingress \
          --group-id ${aws_security_group.jump_host.id} \
          --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$CIDR,Description='Bootstrap SSH'}]" >/dev/null 2>&1 || true
      done
    EOT
  }
}

resource "aws_eip_association" "jump_host" {
  allocation_id = var.bastion_eip_allocation_id
  instance_id   = aws_instance.jump_host.id
}
