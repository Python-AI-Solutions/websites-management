variable "zone_name" {
  type        = string
  description = "The DNS zone to manage inside Cloudflare."
}

variable "account_id" {
  type        = string
  description = "Optional Cloudflare account ID to disambiguate zones."
  default     = null
}
