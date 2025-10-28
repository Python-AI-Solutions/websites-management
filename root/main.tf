locals {
  all_records = merge(
    { "@" : var.apex_records },
    var.subdomain_records
  )
}

module "zone" {
  source = "../modules/cloudflare-zone"

  zone_name  = var.zone_name
  account_id = var.cloudflare_account_id != "" ? var.cloudflare_account_id : null
}

module "records" {
  source = "../modules/cloudflare-records"

  zone_id         = module.zone.zone_id
  zone_name       = module.zone.zone_name
  records         = local.all_records
  default_ttl     = 3600
  default_proxied = false
}

module "google_workspace" {
  count  = var.gmail_enabled ? 1 : 0
  source = "../modules/google-workspace-email"

  zone_id                  = module.zone.zone_id
  zone_name                = module.zone.zone_name
  spf_txt                  = var.spf_txt
  dmarc_policy             = var.dmarc_policy
  dmarc_rua                = var.dmarc_rua
  dmarc_ruf                = var.dmarc_ruf
  dmarc_pct                = var.dmarc_pct
  google_site_verification = var.google_site_verification
  dkim_records             = var.dkim_records
}
