variable "zone_name" {
  type        = string
  description = "The DNS zone to manage inside Cloudflare."
}

variable "account_id" {
  type        = string
  description = "Cloudflare account ID for the zone."
}
