variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "project_name" {
  description = "Name of the Pages project (must be unique in account)"
  type        = string
}

variable "production_branch" {
  description = "Git branch to use for production deployments"
  type        = string
  default     = "main"
}

variable "build_command" {
  description = "Build command for the Pages project"
  type        = string
  default     = ""
}

variable "destination_dir" {
  description = "Output directory for build artifacts"
  type        = string
  default     = ""
}

variable "custom_domain" {
  description = "Custom domain for the Pages project (e.g., subdomain.example.com)"
  type        = string
  default     = ""
}

variable "zone_id" {
  description = "Cloudflare zone ID for DNS record (required if custom_domain is set)"
  type        = string
  default     = ""
}

variable "zone_name" {
  description = "Zone name (e.g., example.com) for calculating subdomain"
  type        = string
  default     = ""
}

variable "dns_ttl" {
  description = "TTL for DNS CNAME record"
  type        = number
  default     = 3600
}

variable "dns_proxied" {
  description = "Whether to proxy DNS through Cloudflare"
  type        = bool
  default     = false
}

variable "production_env_vars" {
  description = "Environment variables for production deployments"
  type        = map(string)
  default     = {}
}

variable "preview_env_vars" {
  description = "Environment variables for preview deployments"
  type        = map(string)
  default     = {}
}
