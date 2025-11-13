resource "aws_instance" "jump_host" {
  ami                         = var.jump_host_ami
  instance_type               = var.jump_host_instance_type
  subnet_id                   = var.jump_host_subnet_id
  private_ip                  = var.jump_host_private_ip
  key_name                    = var.jump_host_key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jump_host.id]
  monitoring                  = false
  ebs_optimized               = false

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
    prevent_destroy = true
  }
}

resource "aws_eip" "jump_host" {
  domain   = "vpc"
  instance = aws_instance.jump_host.id
  tags     = var.jump_host_eip_tags

  lifecycle {
    prevent_destroy = true
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
    description = "Application access"
    from_port   = 7005
    to_port     = 7005
    protocol    = "tcp"
    cidr_blocks = var.jump_host_port_7005_cidrs
  }

  ingress {
    description = "WireGuard VPN"
    from_port   = var.wireguard_listen_port
    to_port     = var.wireguard_listen_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
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
}

resource "null_resource" "wireguard_server" {
  depends_on = [
    aws_instance.jump_host,
    aws_security_group.jump_host
  ]

  triggers = {
    wireguard_address     = var.wireguard_address
    wireguard_listen_port = var.wireguard_listen_port
    wireguard_peers_hash  = sha1(jsonencode(var.wireguard_peers))
    script_hash           = filesha1("${path.module}/scripts/wireguard-bootstrap.sh")
  }

  connection {
    host    = aws_eip.jump_host.public_ip
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
      "sudo WG_ADDRESS='${var.wireguard_address}' WG_PORT='${var.wireguard_listen_port}' WG_PEERS_B64='${base64encode(jsonencode(var.wireguard_peers))}' /home/${var.jump_host_admin_user}/wireguard-bootstrap.sh"
    ]
  }
}
