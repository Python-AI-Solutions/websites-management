output "namespace" {
  description = "Namespace where oauth2-proxy resources were created."
  value       = local.namespace
}

output "deployment_name" {
  description = "Name of the oauth2-proxy Deployment."
  value       = local.deployment_name
}

output "service_name" {
  description = "Name of the oauth2-proxy Service."
  value       = local.service_name
}

output "secret_name" {
  description = "Name of the Kubernetes Secret containing OAuth credentials."
  value       = local.secret_name
}

output "cookie_secret" {
  description = "Base64-encoded cookie secret used by oauth2-proxy."
  value       = local.generated_secret
  sensitive   = true
}

output "args" {
  description = "Final list of command-line arguments applied to oauth2-proxy."
  value       = local.all_args
}

output "redirect_url" {
  description = "Redirect URL configured for oauth2-proxy."
  value       = var.redirect_url
}

output "upstreams" {
  description = "List of upstreams configured for oauth2-proxy."
  value       = var.upstreams
}
