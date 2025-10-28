variable "zone_id" {
  type        = string
  description = "Cloudflare zone identifier."
}

variable "zone_name" {
  type        = string
  description = "Zone name (used to build fully-qualified record names)."
}

variable "records" {
  description = "Map of DNS record definitions keyed by relative hostname. Use '@' for apex records."
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

variable "default_ttl" {
  type        = number
  description = "Fallback TTL applied when a record omits ttl."
  default     = 3600
}

variable "default_proxied" {
  type        = bool
  description = "Fallback Cloudflare proxy mode applied when a record omits proxied."
  default     = false
}
