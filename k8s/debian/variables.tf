# Debian Host Configuration Variables

variable "debian_host_ip" {
  description = "IP address or hostname of Debian host (for SSH access)"
  type        = string
  # Example: "203.0.113.42" or "debian.example.com"
}

variable "debian_ssh_user" {
  description = "SSH user for Debian host"
  type        = string
  default     = "ubuntu"
}

variable "debian_ssh_private_key_path" {
  description = "Path to SSH private key for Debian host access"
  type        = string
  # Example: "~/.ssh/debian_key"
}

variable "debian_wireguard_ip" {
  description = "WireGuard VPN IP for Debian host (MUST be 10.99.0.20)"
  type        = string
  default     = "10.99.0.20"

  validation {
    condition     = var.debian_wireguard_ip == "10.99.0.20"
    error_message = "Debian WireGuard IP must be 10.99.0.20 (for VPN peer registration)"
  }
}

variable "debian_wireguard_private_key" {
  description = "WireGuard private key for Debian host"
  type        = string
  sensitive   = true
  # Generate with: wg genkey
}

variable "bastion_public_ip" {
  description = "Public IP of AWS bastion/jump host"
  type        = string
  # Example: "203.0.113.1"
}

variable "bastion_private_ip" {
  description = "Private IP of AWS bastion/jump host (for FRP server connection)"
  type        = string
  # Example: "10.0.1.50"
}

variable "bastion_ssh_user" {
  description = "SSH user for bastion host"
  type        = string
  default     = "ubuntu"
}

variable "bastion_wireguard_public_key" {
  description = "WireGuard public key of bastion"
  type        = string
  # Generate with: wg pubkey (from bastion's private key)
}

variable "wireguard_port" {
  description = "WireGuard VPN listening port"
  type        = number
  default     = 51820

  validation {
    condition     = var.wireguard_port > 1024 && var.wireguard_port < 65535
    error_message = "WireGuard port must be between 1024 and 65535"
  }
}

variable "frp_token" {
  description = "FRP authentication token (must match bastion FRP server token)"
  type        = string
  sensitive   = true
  default     = "change-me-in-production"
}

variable "frp_server_port" {
  description = "FRP server port (on bastion)"
  type        = number
  default     = 7000

  validation {
    condition     = var.frp_server_port > 1000 && var.frp_server_port < 65535
    error_message = "FRP server port must be between 1000 and 65535"
  }
}

variable "tags" {
  description = "Common tags for Debian resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "production"
    Component   = "debian-host"
  }
}
