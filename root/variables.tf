variable "cloudflare_api_token" {
  type        = string
  description = "Optional Cloudflare API token override; defaults to CLOUDFLARE_API_TOKEN env."
  default     = ""
}

variable "cloudflare_account_id" {
  type        = string
  description = "Optional Cloudflare account ID for API scoping."
  default     = ""
}

variable "zone_name" {
  type        = string
  description = "Primary DNS zone to manage."
  default     = "pythonaisolutions.com"
}

variable "gmail_enabled" {
  type        = bool
  description = "Toggle Google Workspace DNS management."
  default     = true
}

variable "spf_txt" {
  type        = string
  description = "SPF record body for the zone apex."
  default     = "v=spf1 include:_spf.google.com ~all"
}

variable "dmarc_policy" {
  type        = string
  description = "DMARC policy (none, quarantine, reject)."
  default     = "quarantine"
}

variable "dmarc_rua" {
  type        = string
  description = "DMARC aggregate report mailbox."
  default     = "mailto:dmarc@pythonaisolutions.com"
}

variable "dmarc_ruf" {
  type        = string
  description = "DMARC forensic report mailbox."
  default     = ""
}

variable "dmarc_pct" {
  type        = number
  description = "Percentage of messages that DMARC policy applies to."
  default     = 100
}

variable "google_site_verification" {
  type        = string
  description = "Google site verification token (without google-site-verification= prefix)."
  default     = ""
}

variable "dkim_records" {
  description = "DKIM selectors and placeholder values supplied by Google Workspace."
  type = list(object({
    selector = string
    value    = string
    ttl      = optional(number)
  }))
  default = []
}

variable "apex_records" {
  description = "DNS records applied to the zone apex."
  type = object({
    a = optional(list(object({
      value   = string
      ttl     = optional(number)
      proxied = optional(bool)
    })), [])
    aaaa = optional(list(object({
      value   = string
      ttl     = optional(number)
      proxied = optional(bool)
    })), [])
    cname = optional(list(object({
      value   = string
      ttl     = optional(number)
      proxied = optional(bool)
    })), [])
    txt = optional(list(object({
      value = string
      ttl   = optional(number)
    })), [])
    mx = optional(list(object({
      value    = string
      priority = number
      ttl      = optional(number)
    })), [])
    caa = optional(list(object({
      tag   = string
      value = string
      flags = number
      ttl   = optional(number)
    })), [])
    ns = optional(list(object({
      value = string
      ttl   = optional(number)
    })), [])
    srv = optional(list(object({
      service  = string
      proto    = string
      name     = string
      priority = number
      weight   = number
      port     = number
      target   = string
      ttl      = optional(number)
    })), [])
  })
  default = {
    a     = []
    aaaa  = []
    cname = []
    txt   = []
    mx    = []
    caa   = []
    ns    = []
    srv   = []
  }
}

variable "subdomain_records" {
  description = "Map of subdomain record definitions keyed by relative hostname."
  type = map(object({
    a = optional(list(object({
      value   = string
      ttl     = optional(number)
      proxied = optional(bool)
    })), [])
    aaaa = optional(list(object({
      value   = string
      ttl     = optional(number)
      proxied = optional(bool)
    })), [])
    cname = optional(list(object({
      value   = string
      ttl     = optional(number)
      proxied = optional(bool)
    })), [])
    txt = optional(list(object({
      value = string
      ttl   = optional(number)
    })), [])
    mx = optional(list(object({
      value    = string
      priority = number
      ttl      = optional(number)
    })), [])
    caa = optional(list(object({
      tag   = string
      value = string
      flags = number
      ttl   = optional(number)
    })), [])
    ns = optional(list(object({
      value = string
      ttl   = optional(number)
    })), [])
    srv = optional(list(object({
      service  = string
      proto    = string
      name     = string
      priority = number
      weight   = number
      port     = number
      target   = string
      ttl      = optional(number)
    })), [])
  }))
  default = {}
}
