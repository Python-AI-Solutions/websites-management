variable "zone_id" {
  type        = string
  description = "Cloudflare zone identifier."
}

variable "zone_name" {
  type        = string
  description = "DNS zone name."
}

variable "enabled" {
  type        = bool
  description = "Whether to manage Google Workspace records."
  default     = true
}

variable "mx_ttl" {
  type        = number
  description = "TTL applied to MX records."
  default     = 3600
}

variable "spf_txt" {
  type        = string
  description = "SPF policy text value."
  default     = "v=spf1 include:_spf.google.com ~all"
}

variable "spf_ttl" {
  type        = number
  description = "TTL for the SPF TXT record."
  default     = 3600
}

variable "dmarc_policy" {
  type        = string
  description = "DMARC policy (none, quarantine, reject)."
  default     = "quarantine"
}

variable "dmarc_rua" {
  type        = string
  description = "Aggregate report mailbox."
  default     = "mailto:dmarc@pythonaisolutions.com"
}

variable "dmarc_ruf" {
  type        = string
  description = "Forensic report mailbox."
  default     = ""
}

variable "dmarc_pct" {
  type        = number
  description = "Percentage of messages to which the DMARC policy applies."
  default     = 100
}

variable "dmarc_ttl" {
  type        = number
  description = "TTL for the DMARC TXT record."
  default     = 3600
}

variable "google_site_verification" {
  type        = string
  description = "Optional Google site verification TXT token."
  default     = ""
}

variable "site_verification_ttl" {
  type        = number
  description = "TTL for the Google site verification TXT record."
  default     = 3600
}

variable "dkim_records" {
  description = "List of DKIM selectors and values."
  type = list(object({
    selector = string
    value    = string
    ttl      = optional(number)
  }))
  default = []
}
