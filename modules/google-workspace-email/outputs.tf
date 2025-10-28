output "mx_record_ids" {
  description = "Map of MX record IDs keyed by index."
  value       = { for k, v in cloudflare_record.mx : k => v.id }
}

output "spf_record_id" {
  description = "Identifier of the SPF TXT record."
  value       = try(cloudflare_record.spf[0].id, null)
}

output "dmarc_record_id" {
  description = "Identifier of the DMARC TXT record."
  value       = try(cloudflare_record.dmarc[0].id, null)
}

output "site_verification_id" {
  description = "Identifier of the Google site verification TXT record."
  value       = try(cloudflare_record.site_verification[0].id, null)
}

output "dkim_record_ids" {
  description = "Map of DKIM TXT record IDs keyed by selector."
  value       = { for k, v in cloudflare_record.dkim : k => v.id }
}
