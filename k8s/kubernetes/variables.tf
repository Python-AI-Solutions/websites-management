# SSH / Host Configuration
# Authentication uses SSH agent only - ensure keys are loaded with ssh-add
variable "host" {
  description = "Remote Debian host IP or DNS name"
  type        = string
  default     = "localhost"
}

variable "host_port" {
  description = "SSH port for the remote host"
  type        = number
  default     = 7006
}

variable "ssh_user" {
  description = "SSH username for remote host"
  type        = string
  default     = "sysadmin"
}

# Optional Bastion/Jump Host Configuration
variable "bastion_host" {
  description = "Bastion/jump host for SSH access (optional)"
  type        = string
  default     = "3.82.253.109"
}

variable "bastion_user" {
  description = "Username for bastion host"
  type        = string
  default     = "newuser"
}

variable "bastion_port" {
  description = "Port for bastion host"
  type        = number
  default     = 22
}

# Kubernetes Cluster Configuration
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

# Helm Chart Versions
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

# Optional: ACME Configuration for cert-manager
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

# WireGuard Configuration
variable "wireguard_server_public_key" {
  description = "Public key of the WireGuard server (bastion host)"
  type        = string
  default     = ""  # Override via CLI or terraform.tfvars when rotating keys
}

variable "debian_wireguard_private_key" {
  description = "Private key for the Debian host WireGuard interface (must be kept secret)"
  type        = string
  sensitive   = true  # Redacts from logs and output
  default     = ""    # Provide via CLI/terraform.tfvars when configuring the host (KEEP SECURE!)
}

# Firewall Configuration
variable "debian_allowed_ports" {
  description = "List of ports to allow through the firewall"
  type = list(object({
    protocol = string
    port     = number
    comment  = string
  }))
  default = [
    # SSH
    { protocol = "tcp", port = 22, comment = "SSH" },
    # WireGuard
    { protocol = "udp", port = 51820, comment = "WireGuard VPN" },
    # Kubernetes API
    { protocol = "tcp", port = 6443, comment = "Kubernetes API" },
    # HTTP/HTTPS (for Traefik ingress)
    { protocol = "tcp", port = 80, comment = "HTTP" },
    { protocol = "tcp", port = 443, comment = "HTTPS" }
    # Note: NodePort range (30000-32767) is handled separately in firewall rules
  ]
}
