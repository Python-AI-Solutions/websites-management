output "zone_id" {
  description = "The Cloudflare zone identifier."
  value       = cloudflare_zone.this.id
}

output "zone_name" {
  description = "The Cloudflare zone name."
  value       = cloudflare_zone.this.zone
}

output "name_servers" {
  description = "The Cloudflare-assigned authoritative name servers."
  value       = cloudflare_zone.this.name_servers
}
