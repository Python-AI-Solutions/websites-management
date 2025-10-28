locals {
  mx_records = [
    {
      priority = 1
      value    = "ASPMX.L.GOOGLE.COM."
    },
    {
      priority = 5
      value    = "ALT1.ASPMX.L.GOOGLE.COM."
    },
    {
      priority = 5
      value    = "ALT2.ASPMX.L.GOOGLE.COM."
    },
    {
      priority = 10
      value    = "ALT3.ASPMX.L.GOOGLE.COM."
    },
    {
      priority = 10
      value    = "ALT4.ASPMX.L.GOOGLE.COM."
    },
  ]

  dmarc_parts = compact([
    "v=DMARC1",
    "p=${var.dmarc_policy}",
    "pct=${var.dmarc_pct}",
    var.dmarc_rua != "" ? "rua=${var.dmarc_rua}" : "",
    var.dmarc_ruf != "" ? "ruf=${var.dmarc_ruf}" : ""
  ])

  dmarc_value = join("; ", local.dmarc_parts)

  dkim_map = { for record in var.dkim_records : record.selector => record }
}

resource "cloudflare_record" "mx" {
  for_each = var.enabled ? { for idx, record in local.mx_records : idx => record } : {}

  zone_id  = var.zone_id
  name     = var.zone_name
  type     = "MX"
  ttl      = var.mx_ttl
  priority = each.value.priority
  value    = each.value.value
}

resource "cloudflare_record" "spf" {
  count = var.enabled && var.spf_txt != "" ? 1 : 0

  zone_id = var.zone_id
  name    = var.zone_name
  type    = "TXT"
  ttl     = var.spf_ttl
  value   = var.spf_txt
}

resource "cloudflare_record" "dmarc" {
  count = var.enabled ? 1 : 0

  zone_id = var.zone_id
  name    = "_dmarc"
  type    = "TXT"
  ttl     = var.dmarc_ttl
  value   = local.dmarc_value
}

resource "cloudflare_record" "site_verification" {
  count = var.enabled && var.google_site_verification != "" ? 1 : 0

  zone_id = var.zone_id
  name    = var.zone_name
  type    = "TXT"
  ttl     = var.site_verification_ttl
  value   = "google-site-verification=${var.google_site_verification}"
}

resource "cloudflare_record" "dkim" {
  for_each = var.enabled ? local.dkim_map : {}

  zone_id = var.zone_id
  name    = "${each.value.selector}._domainkey"
  type    = "TXT"
  ttl     = try(each.value.ttl, var.spf_ttl)
  value   = each.value.value
}
