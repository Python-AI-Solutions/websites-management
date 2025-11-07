# SSH / Host Configuration
variable "host" {
  description = "Remote Debian host IP or DNS name"
  type        = string
}

variable "ssh_user" {
  description = "SSH username for remote host"
  type        = string
  default     = "sysadmin"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for authentication"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

# Optional Bastion/Jump Host Configuration
variable "bastion_host" {
  description = "Bastion/jump host for SSH access (optional)"
  type        = string
  default     = ""
}

variable "bastion_user" {
  description = "Username for bastion host"
  type        = string
  default     = ""
}

variable "bastion_port" {
  description = "Port for bastion host"
  type        = number
  default     = 22
}

variable "bastion_private_key_path" {
  description = "Path to private key for bastion host"
  type        = string
  default     = ""
}

# Kubernetes Cluster Configuration
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "xps-cluster"
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
