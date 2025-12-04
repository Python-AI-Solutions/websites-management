variable "aws_region" {
  description = "AWS region that hosts the shared infrastructure."
  type        = string
  default     = "us-east-1"
}

variable "jump_host_ami" {
  description = "AMI ID for jump host (e.g., ami-0c55b159cbfafe1f0 for Debian). REQUIRED: provide in terraform.tfvars"
  type        = string
}

variable "jump_host_instance_type" {
  description = "Instance size for the jump host."
  type        = string
  default     = "t2.micro"
}

variable "jump_host_key_name" {
  description = "SSH key pair that must stay attached to the instance."
  type        = string
  default     = "jump_proxy"
}

variable "jump_host_admin_user" {
  description = "SSH username with sudo access on the jump host."
  type        = string
  default     = "admin"
}

variable "jump_host_admin_authorized_key" {
  description = "Public key to authorize for the admin user via cloud-init/user_data."
  type        = string
  sensitive   = true
}

variable "jump_host_jump_user" {
  description = "Non-privileged jump user account that should always exist on the bastion."
  type        = string
  default     = "newuser"
}

variable "jump_host_jump_user_public_key" {
  description = "SSH public key authorized for the jump user (e.g., contents of ~/.ssh/jumpproxy.pub)."
  type        = string
  sensitive   = true
}

variable "jump_host_bootstrap_ssh_cidrs" {
  description = "Temporary CIDRs allowed to reach SSH during bootstrap (removed automatically after WireGuard is configured)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "jump_host_subnet_id" {
  description = "Subnet ID where jump host instance lives (format: subnet-xxxxxxxxx). REQUIRED: provide in terraform.tfvars"
  type        = string
}

variable "jump_host_private_ip" {
  description = "Static private IP for the instance (must be in subnet CIDR). REQUIRED: provide in terraform.tfvars"
  type        = string
}

variable "jump_host_vpc_id" {
  description = "VPC ID for security groups (format: vpc-xxxxxxxxx). REQUIRED: provide in terraform.tfvars"
  type        = string
}

variable "jump_host_security_group_name" {
  description = "Name of the security group attached to the jump host."
  type        = string
  default     = "launch-wizard-1"
}

variable "jump_host_security_group_description" {
  description = "Security group description."
  type        = string
  default     = "launch-wizard-1 created 2024-11-25T14:25:31.878Z"
}

variable "jump_host_ssh_cidrs" {
  description = "CIDR blocks allowed to access SSH on the jump host."
  type        = list(string)
  default = ["10.99.0.0/24"]
}

variable "jump_host_port_7005_cidrs" {
  description = "CIDR blocks allowed to access TCP port 7005 on the jump host (FRP control). Define in terraform.tfvars"
  type        = list(string)
  default     = []
}

variable "jump_host_port_7006_cidrs" {
  description = "CIDR blocks allowed to access TCP port 7006 on the jump host (FRP SSH tunnel). Define in terraform.tfvars"
  type        = list(string)
  default     = []
}

variable "enable_frp_access" {
  description = "Set to true to expose FRP control/tunnel ports (7005/7006)."
  type        = bool
  default     = false
}

variable "jump_host_security_group_tags" {
  description = "Tags applied to the managed security group."
  type        = map(string)
  default     = {}
}

variable "jump_host_root_volume_size" {
  description = "Size (GiB) of the gp3 root volume."
  type        = number
  default     = 30
}

variable "jump_host_root_volume_iops" {
  description = "Provisioned IOPS for the gp3 root volume."
  type        = number
  default     = 3000
}

variable "jump_host_root_volume_throughput" {
  description = "Provisioned throughput (MiB/s) for the gp3 root volume."
  type        = number
  default     = 125
}

variable "jump_host_root_volume_encrypted" {
  description = "Whether the root volume is encrypted."
  type        = bool
  default     = true
}

variable "jump_host_root_volume_kms_key_id" {
  description = "KMS key ARN that encrypts the root volume (format: arn:aws:kms:REGION:ACCOUNT_ID:key/KEY_ID). Optional - provide in terraform.tfvars if needed"
  type        = string
  default     = ""
}

variable "jump_host_tags" {
  description = "Tags that exist (or should exist) on the jump host EC2 instance."
  type        = map(string)
  default     = {}
}

variable "jump_host_eip_tags" {
  description = "Tags that exist (or should exist) on the elastic IP."
  type        = map(string)
  default = {
    "nih-vendor" = ""
  }
}

variable "bastion_eip_allocation_id" {
  description = "Allocation ID of the bastion EIP managed by the eips module."
  type        = string
}

variable "bastion_public_ip" {
  description = "Public IP address of the bastion (output from the persistent EIP module)."
  type        = string
}

variable "bastion_wireguard_private_key" {
  description = "Private key that should be installed on the bastion WireGuard interface (keeps VPN identity stable)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "wireguard_address" {
  description = "WireGuard interface address (with CIDR) assigned to the jump host."
  type        = string
  default     = "10.99.0.1/24"
}

variable "wireguard_listen_port" {
  description = "UDP port WireGuard listens on."
  type        = number
  default     = 51820
}

variable "wireguard_peers" {
  description = "List of WireGuard peers (public keys and allowed IPs) to configure on the server."
  type = list(object({
    name                = optional(string)
    public_key          = string
    allowed_ips         = list(string)
    persistent_keepalive = optional(number, 25)
    endpoint             = optional(string)
  }))
  default = []
}

variable "jump_host_root_volume_type" {
  description = "EBS volume type for jump host root volume (gp2, gp3, io1, io2, st1, sc1)"
  type        = string
  default     = "gp3"
}

variable "frp_token" {
  description = "FRP authentication token (must match on server and client)"
  type        = string
  sensitive   = true
  default     = "change-me-in-production"
}

variable "frp_ssh_proxy_port" {
  description = "FRP remote port exposed on the bastion to reach Debian SSH (default 7006)"
  type        = number
  default     = 7006
}
