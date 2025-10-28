output "project_id" {
  description = "ID of the Pages project"
  value       = cloudflare_pages_project.this.id
}

output "project_name" {
  description = "Name of the Pages project"
  value       = cloudflare_pages_project.this.name
}

output "pages_dev_url" {
  description = "Default pages.dev URL for the project"
  value       = "${cloudflare_pages_project.this.name}.pages.dev"
}

output "custom_domain" {
  description = "Custom domain configured for the project"
  value       = var.custom_domain
}

output "subdomain" {
  description = "Subdomain portion (for easy reference)"
  value       = var.custom_domain != "" && var.zone_name != "" ? trimsuffix(var.custom_domain, ".${var.zone_name}") : ""
}
