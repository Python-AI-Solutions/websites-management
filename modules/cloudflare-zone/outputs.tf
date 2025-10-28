output "zone_id" {
  description = "The Cloudflare zone identifier."
  value       = data.cloudflare_zone.this.id
}

output "zone_name" {
  description = "The Cloudflare zone name."
  value       = data.cloudflare_zone.this.name
}

output "name_servers" {
  description = "The Cloudflare-assigned authoritative name servers."
  value       = data.cloudflare_zone.this.name_servers
}
