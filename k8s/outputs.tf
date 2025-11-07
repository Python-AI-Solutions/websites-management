output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = abspath(var.kubeconfig_local_path)
  sensitive   = true
}

output "cluster_info" {
  description = "Basic cluster information"
  value = {
    cluster_name = var.cluster_name
    k8s_version  = var.kubernetes_version
    host         = var.host
  }
}

output "next_steps" {
  description = "Instructions for using the cluster"
  value = <<-EOT
    Cluster setup complete!
    
    To use kubectl with this cluster:
    export KUBECONFIG=${abspath(var.kubeconfig_local_path)}
    
    Verify cluster status:
    kubectl get nodes -o wide
    kubectl get pods -A
    
    Check addon status:
    kubectl -n kube-system get ds cilium
    kubectl -n traefik get deploy traefik
    kubectl -n cert-manager get pods
    kubectl get storageclass
  EOT
}
