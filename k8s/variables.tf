# ============================================================================
# ROOT VARIABLES: Aggregated Configuration for All Modules
# ============================================================================
# This file aggregates variables from:
# - AWS Module (./aws) - Bastion/Jump Host Configuration
# - Debian Module (./debian) - Debian Host Configuration
# - Kubernetes Module (./kubernetes) - K8s Cluster Configuration
# ============================================================================

# ============================================================================
# AWS MODULE VARIABLES
# ============================================================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "jump_host_ami" {
  description = "AMI ID for jump host (bastion)"
  type        = string
  # Ubuntu 22.04 LTS (change per region)
  default     = "ami-0c55b159cbfafe1f0"
}

variable "jump_host_instance_type" {
  description = "Instance type for jump host"
  type        = string
  default     = "t3.small"
}

variable "jump_host_subnet_id" {
  description = "Subnet ID for jump host"
  type        = string
  # Required: provide your VPC subnet ID
}

variable "jump_host_private_ip" {
  description = "Private IP for jump host (optional)"
  type        = string
  default     = ""  # Let AWS assign
}

variable "jump_host_key_name" {
  description = "SSH key pair name in AWS"
  type        = string
  # Required: must exist in AWS account
}

variable "jump_host_vpc_id" {
  description = "VPC ID for security groups"
  type        = string
  # Required: your VPC ID
}

variable "jump_host_admin_user" {
  description = "Default admin user on jump host AMI"
  type        = string
  default     = "ubuntu"
}

variable "jump_host_security_group_name" {
  description = "Name for jump host security group"
  type        = string
  default     = "bastion-sg"
}

variable "jump_host_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH to bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict in production!
}

variable "jump_host_port_7005_cidrs" {
  description = "CIDR blocks allowed for FRP control port"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "jump_host_port_7006_cidrs" {
  description = "CIDR blocks allowed for FRP SSH tunnel"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "jump_host_tags" {
  description = "Tags for jump host instance"
  type        = map(string)
  default = {
    Name        = "bastion-host"
    Environment = "production"
    Terraform   = "true"
  }
}

variable "jump_host_eip_tags" {
  description = "Tags for jump host EIP"
  type        = map(string)
  default = {
    Name        = "bastion-eip"
    Environment = "production"
  }
}

variable "jump_host_security_group_tags" {
  description = "Tags for jump host security group"
  type        = map(string)
  default = {
    Name        = "bastion-sg"
    Environment = "production"
  }
}

variable "jump_host_root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 30
}

variable "jump_host_root_volume_encrypted" {
  description = "Encrypt root volume"
  type        = bool
  default     = true
}

variable "jump_host_root_volume_kms_key_id" {
  description = "KMS key ID for volume encryption (optional)"
  type        = string
  default     = ""
}

variable "jump_host_root_volume_iops" {
  description = "IOPS for root volume (gp3)"
  type        = number
  default     = 3000
}

variable "jump_host_root_volume_throughput" {
  description = "Throughput for root volume (gp3)"
  type        = number
  default     = 125
}

# ============================================================================
# WIREGUARD SERVER CONFIGURATION (on AWS Bastion)
# ============================================================================

variable "wireguard_address" {
  description = "WireGuard server address (VPN subnet)"
  type        = string
  default     = "10.99.0.1/24"
}

variable "wireguard_listen_port" {
  description = "WireGuard listening port"
  type        = number
  default     = 51820
}

variable "wireguard_peers" {
  description = "WireGuard peers configuration"
  type = list(object({
    name                 = string
    public_key           = string
    allowed_ips          = list(string)
    persistent_keepalive = number
  }))
  default = [
    {
      name                 = "debian-host"
      public_key           = ""  # Will be provided via tfvars
      allowed_ips          = ["10.99.0.20/32"]
      persistent_keepalive = 25
    }
  ]
}

# ============================================================================
# FRP CONFIGURATION
# ============================================================================

variable "enable_frp_emergency" {
  description = "Enable FRP emergency access (auto-enabled when Debian health check fails)"
  type        = bool
  default     = false
}

variable "frp_server_port" {
  description = "FRP server port"
  type        = number
  default     = 7000
}

variable "frp_token" {
  description = "FRP authentication token (must match on server and client)"
  type        = string
  sensitive   = true
  default     = "change-me-in-production"
}

# ============================================================================
# DEBIAN MODULE VARIABLES
# ============================================================================

variable "debian_host_ip" {
  description = "IP address or hostname of Debian host (for SSH access)"
  type        = string
  # Example: "203.0.113.42" or "debian.example.com"
  # Required: must be provided
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
  # Required: must be provided
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
  # Required: must be provided
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
  # Required: must be provided
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

# ============================================================================
# KUBERNETES MODULE VARIABLES
# ============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k8s"
}

variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.30.5"
}

variable "pod_cidr" {
  description = "CIDR range for pod network"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR range for service network"
  type        = string
  default     = "10.96.0.0/12"
}

variable "control_plane_endpoint" {
  description = "Control plane endpoint (leave empty for single node)"
  type        = string
  default     = ""
}

variable "kubeconfig_local_path" {
  description = "Local path to save the kubeconfig file"
  type        = string
  default     = "./kubeconfig"
}

# ============================================================================
# HELM CHART VERSIONS
# ============================================================================

variable "cilium_chart_version" {
  description = "Version of Cilium Helm chart"
  type        = string
  default     = "1.16.3"
}

variable "traefik_chart_version" {
  description = "Version of Traefik Helm chart"
  type        = string
  default     = "32.1.0"
}

variable "cert_manager_chart_version" {
  description = "Version of cert-manager Helm chart"
  type        = string
  default     = "v1.16.1"
}

variable "local_path_provisioner_chart_version" {
  description = "Version of local-path-provisioner Helm chart"
  type        = string
  default     = "0.0.28"
}

variable "acme_email" {
  description = "Email address for ACME certificate registration (Let's Encrypt)"
  type        = string
  default     = ""
}

variable "enable_letsencrypt_staging" {
  description = "Use Let's Encrypt staging server (for testing)"
  type        = bool
  default     = true
}

# ============================================================================
# FIREWALL CONFIGURATION
# ============================================================================

variable "debian_allowed_ports" {
  description = "List of ports to allow through the firewall"
  type = list(object({
    protocol = string
    port     = number
    comment  = string
  }))
  default = [
    { protocol = "tcp", port = 22, comment = "SSH" },
    { protocol = "udp", port = 51820, comment = "WireGuard VPN" },
    { protocol = "tcp", port = 6443, comment = "Kubernetes API" },
    { protocol = "tcp", port = 80, comment = "HTTP" },
    { protocol = "tcp", port = 443, comment = "HTTPS" }
  ]
}
