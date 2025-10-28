locals {
  record_ids = merge(
    { for k, v in cloudflare_record.a : k => v.id },
    { for k, v in cloudflare_record.aaaa : k => v.id },
    { for k, v in cloudflare_record.cname : k => v.id },
    { for k, v in cloudflare_record.txt : k => v.id },
    { for k, v in cloudflare_record.mx : k => v.id },
    { for k, v in cloudflare_record.caa : k => v.id },
    { for k, v in cloudflare_record.ns : k => v.id },
    { for k, v in cloudflare_record.srv : k => v.id }
  )
}

output "record_ids" {
  description = "Map of record identifiers keyed by internal handle."
  value       = local.record_ids
}
