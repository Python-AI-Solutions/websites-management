# Debian Host Configuration Variables

variable "debian_host_ip" {
  description = "IP address or hostname of Debian host (for SSH access)"
  type        = string
  default     = "10.99.0.2"
}

variable "debian_ssh_user" {
  description = "SSH user for Debian host"
  type        = string
  default     = "sysadmin"
}

variable "debian_wireguard_ip" {
  description = "WireGuard VPN IP for Debian host (MUST be 10.99.0.2)"
  type        = string
  default     = "10.99.0.2"

  validation {
    condition     = var.debian_wireguard_ip == "10.99.0.2"
    error_message = "Debian WireGuard IP must be 10.99.0.2 for peer registration)"
  }
}

variable "debian_wireguard_private_key" {
  description = "WireGuard private key for Debian"
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
  default     = "admin"
}

variable "bastion_wireguard_public_key" {
  description = "WireGuard public key of bastion"
  type        = string
  default     = "39oLcmw2XRX57PguWfsqlZmURajuRJQiUUj+mvqIWhU="
}

variable "bastion_wireguard_host" {
  description = "Bastion IP inside the WireGuard network (used as SSH jump host)"
  type        = string
  default     = "10.99.0.1"
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

variable "debian_wireguard_admin_cidrs" {
  description = "List of WireGuard /32s that should be allowed to SSH to Debian (e.g., bastion + laptop peers)."
  type        = list(string)
  default     = ["10.99.0.1/32"]
}

variable "frp_token" {
  description = "FRP authentication token (must match bastion FRP server token)"
  type        = string
  sensitive   = true
  default     = "change-me-in-production"
}

variable "frp_server_port" {
  description = "FRP server control port (on bastion)"
  type        = number
  default     = 7005

  validation {
    condition     = var.frp_server_port > 1000 && var.frp_server_port < 65535
    error_message = "FRP server port must be between 1000 and 65535"
  }
}

variable "frp_ssh_proxy_port" {
  description = "FRP remote port that forwards Debian SSH through the bastion"
  type        = number
  default     = 7006

  validation {
    condition     = var.frp_ssh_proxy_port > 1000 && var.frp_ssh_proxy_port < 65535
    error_message = "FRP SSH proxy port must be between 1000 and 65535"
  }
}

variable "enable_frp_emergency" {
  description = "Whether FRP emergency mode is enabled (controls documentation/outputs)"
  type        = bool
  default     = false
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
