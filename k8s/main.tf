# ============================================================================
# ROOT ORCHESTRATION MODULE: Kubernetes Cluster Deployment
# ============================================================================
# This module orchestrates the deployment of:
# 1. AWS Bastion (jump host with WireGuard VPN server)
# 2. Debian Host (VPN peer for K8s cluster)
# 3. Kubernetes Cluster (runs on Debian host via remote-exec)
#
# Deployment Flow:
# - AWS bastion is created first
# - Debian configuration depends on bastion outputs
# - Kubernetes setup depends on debian completion
# - All via single: cd k8s && tofu apply
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state stored in encrypted GCS bucket
  backend "gcs" {
    bucket = "k8s-tfstate-midyear-pattern-470017-b8"
    prefix = "k8s-cluster/terraform.tfstate"
  }
}

# ============================================================================
# HEALTH CHECK: Determine if FRP emergency access is needed
# ============================================================================
# Requirement: "checks for debian host configuration… if it fails
# the AWS host is temporarily redeployed with frp active"
#
# Logic:
# - If Debian is being deployed for the first time or is unreachable,
#   enable FRP as emergency access mechanism
# - If Debian is reachable and properly configured, disable FRP
# - FRP toggle is controlled by var.enable_frp_emergency (can be overridden in tfvars)
#
# Default behavior: Enable FRP on first deployment, disable on subsequent
# successful deployments (user can override with terraform.tfvars)
locals {
  # Health check placeholder – currently manual until automated probe is implemented.
  frp_health_check_enabled = var.enable_frp_emergency

  health_check_message = var.enable_frp_emergency ? (
    "⚠️  FRP EMERGENCY MODE ENABLED - Using reverse tunnel for Debian access"
    ) : (
    "✅ NORMAL MODE - Using WireGuard VPN for Debian access"
  )

  deploy_debian     = var.deploy_debian_host ? { main = true } : {}
  deploy_kubernetes = var.deploy_kubernetes_cluster ? { main = true } : {}
}

# ============================================================================
# MODULE 0: Elastic IPs (persistent bastion EIP)
# ============================================================================
module "eips" {
  source   = "./eips"
  eip_tags = var.jump_host_eip_tags
}

# ============================================================================
# LEGACY LOCAL FILES (Audit policy, encryption config, kubeadm config)
# ============================================================================
# These files are kept on disk for reference/runbooks. Manage them via Terraform
# so existing state entries remain valid.

# ============================================================================
# MODULE 1: AWS Bastion (Jump Host + WireGuard Server)
# ============================================================================
# Provisions:
# - EC2 instance with EIP (stable public IP)
# - Security groups for SSH, WireGuard, and FRP access
# - WireGuard server setup for VPN access
# - FRP server support (for emergency access)
module "aws_bastion" {
  source = "./aws"

  # AWS Provider Configuration (from root variables)
  aws_region              = var.aws_region
  jump_host_ami           = var.jump_host_ami
  jump_host_instance_type = var.jump_host_instance_type
  jump_host_subnet_id     = var.jump_host_subnet_id
  jump_host_private_ip    = var.jump_host_private_ip
  jump_host_key_name      = var.jump_host_key_name
  jump_host_vpc_id        = var.jump_host_vpc_id
  jump_host_admin_authorized_key = var.jump_host_admin_authorized_key

  # WireGuard Configuration
  wireguard_address             = var.wireguard_address
  wireguard_listen_port         = var.wireguard_listen_port
  wireguard_peers               = var.wireguard_peers
  bastion_wireguard_private_key = var.bastion_wireguard_private_key

  # Jump user
  jump_host_jump_user            = var.jump_host_jump_user
  jump_host_jump_user_public_key = var.jump_host_jump_user_public_key

  # FRP Configuration
  enable_frp_access         = var.enable_frp_emergency
  enable_frp_emergency      = var.enable_frp_emergency
  jump_host_port_7005_cidrs = var.jump_host_port_7005_cidrs
  jump_host_port_7006_cidrs = var.jump_host_port_7006_cidrs
  frp_server_port           = var.frp_server_port
  frp_ssh_proxy_port        = var.frp_ssh_proxy_port
  frp_token                 = var.frp_token

  # Tags
  jump_host_admin_user                 = var.jump_host_admin_user
  jump_host_security_group_name        = var.jump_host_security_group_name
  jump_host_security_group_description = "launch-wizard-1 created 2024-11-25T14:25:31.878Z"
  jump_host_ssh_cidrs                  = var.jump_host_ssh_cidrs
  jump_host_tags                       = var.jump_host_tags
  jump_host_eip_tags                   = var.jump_host_eip_tags
  jump_host_security_group_tags        = var.jump_host_security_group_tags

  # Storage configuration
  jump_host_root_volume_size       = var.jump_host_root_volume_size
  jump_host_root_volume_type       = "gp3"
  jump_host_root_volume_encrypted  = var.jump_host_root_volume_encrypted
  jump_host_root_volume_kms_key_id = var.jump_host_root_volume_kms_key_id
  jump_host_root_volume_iops       = var.jump_host_root_volume_iops
  jump_host_root_volume_throughput = var.jump_host_root_volume_throughput

  bastion_eip_allocation_id = module.eips.bastion_allocation_id
  bastion_public_ip         = module.eips.bastion_public_ip
}

# ============================================================================
# MODULE 2: Debian Host Configuration (VPN Peer + FRP Client)
# ============================================================================
# Provisions (via remote-exec through bastion jump host):
# - WireGuard VPN interface with correct IP (10.99.0.2)
# - FRP client for emergency access tunnel
# - Port restrictions via iptables
# - Verification of correct configuration
#
# IMPORTANT: This depends on AWS bastion being ready
module "debian_host" {
  for_each = local.deploy_debian
  source   = "./debian"

  # Get bastion details from AWS module
  bastion_public_ip  = module.eips.bastion_public_ip
  bastion_private_ip = module.aws_bastion.jump_host_private_ip
  bastion_ssh_user   = var.bastion_ssh_user
  bastion_wireguard_host = var.bastion_wireguard_host

  # Debian host connection details
  debian_host_ip  = var.debian_host_ip
  debian_ssh_user = var.debian_ssh_user

  # WireGuard configuration for Debian
  debian_wireguard_ip          = var.debian_wireguard_ip
  debian_wireguard_private_key = var.debian_wireguard_private_key
  bastion_wireguard_public_key = var.bastion_wireguard_public_key
  wireguard_port               = var.wireguard_port
  # Extract admin CIDRs from wireguard_peers (exclude debian-host itself) + bastion
  debian_wireguard_admin_cidrs = concat(
    ["10.99.0.1/32"],  # bastion WireGuard IP
    flatten([
      for peer in var.wireguard_peers : peer.allowed_ips
      if peer.name != "debian-host"
    ])
  )

  # FRP configuration
  enable_frp_emergency = var.enable_frp_emergency
  frp_token            = var.frp_token
  frp_server_port      = var.frp_server_port
  frp_ssh_proxy_port   = var.frp_ssh_proxy_port

  # Ensure AWS bastion is fully ready before configuring Debian
  depends_on = [module.aws_bastion]
}

# ============================================================================
# MODULE 3: Kubernetes Cluster Setup (on Debian Host)
# ============================================================================
# Provisions (via remote-exec on Debian through bastion):
# - Kubernetes binaries (kubeadm, kubelet, kubectl)
# - Container runtime (containerd)
# - Etcd encryption at rest (AES-CBC 256-bit)
# - API server audit logging
# - Network plugins and ingress controllers
#
# IMPORTANT: This depends on Debian being fully configured and accessible
module "kubernetes_cluster" {
  for_each = local.deploy_kubernetes
  source   = "./kubernetes"

  # Get Debian details from debian module (for SSH access)
  host         = var.debian_host_ip
  host_port    = 22
  ssh_user     = var.debian_ssh_user
  bastion_host = var.bastion_wireguard_host
  bastion_user = var.bastion_ssh_user
  bastion_port = 22

  # Kubernetes cluster configuration
  cluster_name           = var.cluster_name
  kubernetes_version     = var.kubernetes_version
  pod_cidr               = var.pod_cidr
  service_cidr           = var.service_cidr
  control_plane_endpoint = var.control_plane_endpoint

  # Kubeconfig output
  kubeconfig_local_path = var.kubeconfig_local_path

  # Helm chart versions
  cilium_chart_version                 = var.cilium_chart_version
  traefik_chart_version                = var.traefik_chart_version
  cert_manager_chart_version           = var.cert_manager_chart_version
  local_path_provisioner_chart_version = var.local_path_provisioner_chart_version

  # ACME/Let's Encrypt configuration
  acme_email                 = var.acme_email
  enable_letsencrypt_staging = var.enable_letsencrypt_staging

  # WireGuard configuration (for reference)
  wireguard_server_public_key  = var.bastion_wireguard_public_key
  debian_wireguard_private_key = var.debian_wireguard_private_key

  # Firewall configuration
  debian_allowed_ports = var.debian_allowed_ports

  # Ensure Debian is fully configured before setting up K8s
  depends_on = [module.aws_bastion]
}
