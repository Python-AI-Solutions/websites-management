# ============================================================================
# ROOT OUTPUTS: Orchestration Results
# ============================================================================
# These outputs aggregate results from all three modules:
# - AWS Bastion module
# - Debian Host module
# - Kubernetes Cluster module
# ============================================================================

locals {
  kubernetes_kubeconfig = var.deploy_kubernetes_cluster ? module.kubernetes_cluster["main"].kubeconfig_path : ""

  deployment_summary_success = <<-EOT
    ==========================================================================
    KUBERNETES CLUSTER DEPLOYMENT COMPLETE
    ==========================================================================

    ✅ AWS Bastion:
       Instance ID: ${module.aws_bastion.jump_host_instance_id}
       Public IP:  ${module.eips.bastion_public_ip}
       Private IP: ${module.aws_bastion.jump_host_private_ip}

    ✅ Debian Host:
       WireGuard IP: ${var.debian_wireguard_ip}
       SSH Access:   ssh -J ${var.bastion_ssh_user}@${module.eips.bastion_public_ip} ${var.debian_ssh_user}@${var.debian_host_ip}

    ✅ Kubernetes Cluster:
       Cluster Name: ${var.cluster_name}
       Version:      ${var.kubernetes_version}
       Kubeconfig:   ${local.kubernetes_kubeconfig}

    NEXT STEPS:
    1. Export kubeconfig: export KUBECONFIG=${local.kubernetes_kubeconfig}
    2. Verify cluster:    kubectl get nodes
    3. Check pod status:  kubectl get pods -A

    ==========================================================================
  EOT

  deployment_summary_pending = <<-PENDING
    ==========================================================================
    KUBERNETES CLUSTER DEPLOYMENT PENDING
    ==========================================================================

    - AWS bastion deployed at ${module.eips.bastion_public_ip}
    - Set deploy_debian_host=true once Debian access is restored
    - Enable deploy_kubernetes_cluster=true after Debian provisioning succeeds

    ==========================================================================
  PENDING
}

output "aws_bastion" {
  description = "AWS Bastion (Jump Host) Details"
  value = {
    instance_id = module.aws_bastion.jump_host_instance_id
    public_ip   = module.eips.bastion_public_ip
    private_ip  = module.aws_bastion.jump_host_private_ip
  }
}

output "debian_host" {
  description = "Debian Host VPN Details"
  value = {
    wireguard_ip = var.debian_wireguard_ip
    ssh_user     = var.debian_ssh_user
    access       = "ssh -J ${var.bastion_ssh_user}@${module.eips.bastion_public_ip} ${var.debian_ssh_user}@${var.debian_host_ip}"
  }
  sensitive = true
}

output "kubernetes_cluster" {
  description = "Kubernetes Cluster Details"
  value = var.deploy_kubernetes_cluster ? {
    cluster_name = var.cluster_name
    k8s_version  = var.kubernetes_version
    kubeconfig   = local.kubernetes_kubeconfig
    } : {
    status = "Kubernetes deployment disabled (set deploy_kubernetes_cluster=true when ready)"
  }
  sensitive = true
}

output "deployment_summary" {
  description = "Complete Deployment Summary"
  value       = var.deploy_kubernetes_cluster ? local.deployment_summary_success : local.deployment_summary_pending
  sensitive   = true
}

output "connection_details" {
  description = "Quick reference for connecting to deployed infrastructure"
  value = {
    bastion     = "ssh -i ~/.ssh/<key> ${var.jump_host_admin_user}@${module.eips.bastion_public_ip}"
    debian      = "ssh -J ${var.bastion_ssh_user}@${module.eips.bastion_public_ip} ${var.debian_ssh_user}@${var.debian_host_ip}"
    k8s_via_vpn = "ping ${var.debian_wireguard_ip}"
  }
  sensitive = true
}

output "health_check_status" {
  description = "FRP Emergency Access Status - Indicates deployment mode (Normal VPN or Emergency FRP access)"
  value       = local.health_check_message
}
