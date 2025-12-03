output "namespace" {
  description = "Namespace where Argo CD is installed."
  value       = var.namespace
}

output "helm_release_name" {
  description = "Name of the Argo CD Helm release."
  value       = helm_release.argocd.name
}

output "app_projects" {
  description = "Argo CD projects managed by this module."
  value = {
    for name, manifest in kubernetes_manifest.app_project : name => {
      name      = manifest.manifest["metadata"]["name"]
      namespace = manifest.manifest["metadata"]["namespace"]
    }
  }
}

output "applications" {
  description = "Argo CD applications managed by this module."
  value = {
    for name, manifest in kubernetes_manifest.application : name => {
      name      = manifest.manifest["metadata"]["name"]
      namespace = manifest.manifest["metadata"]["namespace"]
      project   = manifest.manifest["spec"]["project"]
    }
  }
}
