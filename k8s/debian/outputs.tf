# Debian Host Module Outputs
#
# Exports configuration details needed by parent modules (e.g., Kubernetes cluster)
# to reach and configure the Debian host

output "debian_wireguard_ip" {
  description = "WireGuard VPN IP address of Debian host (for K8s cluster to use)"
  value       = var.debian_wireguard_ip
}

output "debian_host_ip" {
  description = "SSH-accessible IP or hostname of Debian host"
  value       = var.debian_host_ip
}

output "debian_ssh_user" {
  description = "SSH user for accessing Debian host"
  value       = var.debian_ssh_user
}

output "bastion_public_ip" {
  description = "Public IP of bastion (needed for K8s to reach Debian via jump host)"
  value       = var.bastion_public_ip
}

output "bastion_ssh_user" {
  description = "SSH user for bastion host"
  value       = var.bastion_ssh_user
}

output "wireguard_port" {
  description = "WireGuard port used for VPN access"
  value       = var.wireguard_port
}
