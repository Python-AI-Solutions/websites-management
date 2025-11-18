variable "aws_region" {
  description = "AWS region that hosts the shared infrastructure."
  type        = string
  default     = "us-east-1"
}

variable "jump_host_ami" {
  description = "AMI currently used by the existing jump host instance."
  type        = string
  default     = "ami-064519b8c76274859"
}

variable "jump_host_instance_type" {
  description = "Instance size for the jump host."
  type        = string
  default     = "t2.micro"
}

variable "jump_host_key_name" {
  description = "SSH key pair that must stay attached to the instance."
  type        = string
  default     = "pas_jump_proxy"
}

variable "jump_host_admin_user" {
  description = "SSH username with sudo access on the jump host."
  type        = string
  default     = "admin"
}

variable "jump_host_subnet_id" {
  description = "Subnet where the instance currently lives."
  type        = string
  default     = "subnet-0bb0d24c4d5f3630f"
}

variable "jump_host_private_ip" {
  description = "Static private IP already assigned to the instance."
  type        = string
  default     = "172.31.82.16"
}

variable "jump_host_vpc_id" {
  description = "VPC that contains the jump host networking resources."
  type        = string
  default     = "vpc-0ac536a2ad40f6d6d"
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
  default = [
    "10.99.0.0/24",
    "109.76.78.109/32",
    "223.190.84.183/32"
  ]
}

variable "jump_host_port_7005_cidrs" {
  description = "CIDR blocks allowed to access TCP port 7005 on the jump host."
  type        = list(string)
  default = [
    "10.99.0.0/24"
  ]
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
  description = "KMS key that encrypts the root volume."
  type        = string
  default     = "arn:aws:kms:us-east-1:302263054204:key/f7a6c94d-a278-4cdb-9e95-e7211ac8d7ec"
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
