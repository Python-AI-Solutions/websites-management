output "zone_id" {
  description = "Cloudflare zone identifier."
  value       = module.zone.zone_id
}

output "zone_name" {
  description = "Cloudflare zone name."
  value       = module.zone.zone_name
}

output "name_servers" {
  description = "Cloudflare nameservers for this zone. Update these at your domain registrar."
  value       = module.zone.name_servers
}

output "record_ids" {
  description = "Map of managed DNS record IDs."
  value       = module.records.record_ids
}

output "google_workspace_record_ids" {
  description = "Identifiers of Google Workspace helper records."
  value = var.gmail_enabled ? {
    mx    = try(module.google_workspace[0].mx_record_ids, {})
    spf   = try(module.google_workspace[0].spf_record_id, null)
    dmarc = try(module.google_workspace[0].dmarc_record_id, null)
    site  = try(module.google_workspace[0].site_verification_id, null)
    dkim  = try(module.google_workspace[0].dkim_record_ids, {})
  } : {}
}

output "pages_projects" {
  description = "Cloudflare Pages projects and their URLs"
  value = {
    for name, project in module.pages_projects : name => {
      project_id    = project.project_id
      pages_dev_url = project.pages_dev_url
      custom_domain = project.custom_domain
      subdomain     = project.subdomain
    }
  }
}
