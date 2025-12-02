# FRP Emergency Access for Debian Host
#
# Purpose: Enable temporary emergency access to Debian host via reverse tunnel
# Usage: Only enable when Debian check fails and normal WireGuard access unavailable
# Status: FRP server port (7000) is CLOSED by default, only opened on emergency
#
# How it works:
# 1. tofu apply checks if Debian is accessible
# 2. If check fails: enable_frp_emergency = true is set
# 3. FRP server port 7000 opens on AWS bastion
# 4. FRP server starts listening for Debian's FRP client
# 5. Debian client connects to server via reverse tunnel
# 6. User can SSH to Debian via: ssh -J ubuntu@aws-bastion ubuntu@debian-host
# 7. Once Debian is healthy: tofu apply again
# 8. enable_frp_emergency auto-disables, port 7000 closes
#
# This avoids IP whitelisting issues and provides reliable emergency access

variable "enable_frp_emergency" {
  description = "Enable FRP server for emergency Debian host access (auto-set by health check, default false)"
  type        = bool
  default     = false

  validation {
    condition     = var.enable_frp_emergency == true || var.enable_frp_emergency == false
    error_message = "enable_frp_emergency must be boolean (true/false)"
  }
}

variable "frp_server_port" {
  description = "FRP server control port (default: 7005)"
  type        = number
  default     = 7005

  validation {
    condition     = var.frp_server_port > 1000 && var.frp_server_port < 65535
    error_message = "FRP server port must be between 1000 and 65535"
  }
}

# Null resource to manage FRP server status on bastion
resource "null_resource" "frp_server_manage" {
  count = var.enable_frp_emergency ? 1 : 0

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Setting up FRP server on bastion (emergency access)...'",
      "# Check if frp is installed",
      "if ! command -v frp &> /dev/null; then",
      "  echo 'Installing FRP server...'",
      "  # Download and install FRP (example for linux_amd64)",
      "  cd /tmp",
      "  wget https://github.com/fatedier/frp/releases/download/v0.50.0/frp_0.50.0_linux_amd64.tar.gz",
      "  tar -xzf frp_0.50.0_linux_amd64.tar.gz",
      "  sudo mv frp_0.50.0_linux_amd64/frps /usr/local/bin/",
      "  rm -rf frp_0.50.0_linux_amd64*",
      "fi",
      "sudo mkdir -p /etc/frp",
      "sudo chmod 755 /etc/frp",
      "sudo mkdir -p /var/log/frp",
      "# Create FRP server config",
      "cat << 'FRPCONF' | sudo tee /etc/frp/frps.ini > /dev/null",
      "[common]",
      "bind_port = ${var.frp_server_port}",
      "token = ${var.frp_token}",
      "log_file = /var/log/frp/frps.log",
      "log_level = info",
      "FRPCONF",
      "# Create systemd service for frp server",
      "cat << 'FRPSVC' | sudo tee /etc/systemd/system/frps.service > /dev/null",
      "[Unit]",
      "Description=FRP Server",
      "After=network.target",
      "[Service]",
      "Type=simple",
      "ExecStart=/usr/local/bin/frps -c /etc/frp/frps.ini",
      "Restart=always",
      "RestartSec=5",
      "[Install]",
      "WantedBy=multi-user.target",
      "FRPSVC",
      "# Start FRP server",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable frps",
      "sudo systemctl start frps",
      "echo 'FRP server started on port ${var.frp_server_port}'",
      "sleep 2"
    ]

    connection {
      type    = "ssh"
      user    = var.jump_host_admin_user
      host    = aws_instance.jump_host.public_ip
      agent   = true
      timeout = "5m"
    }
  }

  triggers = {
    frp_enabled = var.enable_frp_emergency
  }

  depends_on = [aws_security_group.jump_host]
}

# Null resource to disable FRP server when not needed
resource "null_resource" "frp_server_disable" {
  count = var.enable_frp_emergency ? 0 : 1

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Disabling FRP server (normal operation)...'",
      "if systemctl is-active --quiet frps; then",
      "  echo 'Stopping FRP server...'",
      "  sudo systemctl stop frps || true",
      "  echo 'FRP server stopped'",
      "fi"
    ]

    connection {
      type    = "ssh"
      user    = var.jump_host_admin_user
      host    = aws_instance.jump_host.public_ip
      agent   = true
      timeout = "2m"
    }
  }

  triggers = {
    frp_enabled = var.enable_frp_emergency
  }

  depends_on = [aws_instance.jump_host]
}

# Output: FRP server status
output "frp_status" {
  description = "FRP emergency access status"
  value = {
    enabled      = var.enable_frp_emergency
    server_port  = var.enable_frp_emergency ? var.frp_server_port : null
    bastion_ip   = aws_instance.jump_host.public_ip
    emergency_access = var.enable_frp_emergency ? "Enabled - Use: ssh -J ubuntu@${aws_instance.jump_host.public_ip} ubuntu@10.99.0.2" : "Disabled (normal WireGuard access)"
  }
}

output "frp_runbook" {
  description = "FRP emergency access runbook (shows when FRP is enabled)"
  value = var.enable_frp_emergency ? "FRP EMERGENCY ACCESS ACTIVE - Access: ssh -J ubuntu@${aws_instance.jump_host.public_ip} ubuntu@debian-host - To disable: fix Debian VPN config and run tofu apply again" : "FRP disabled (normal operation)"
}
