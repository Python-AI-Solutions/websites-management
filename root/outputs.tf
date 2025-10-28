output "zone_id" {
  description = "Cloudflare zone identifier."
  value       = module.zone.zone_id
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
