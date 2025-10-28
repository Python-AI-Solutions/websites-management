locals {
  all_records = merge(
    { "@" : var.apex_records },
    var.subdomain_records
  )
}

module "zone" {
  source = "../modules/cloudflare-zone"

  zone_name  = var.zone_name
  account_id = var.cloudflare_account_id
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

# Cloudflare Pages projects for static sites
module "pages_projects" {
  for_each = var.pages_projects
  source   = "../modules/cloudflare-pages"

  account_id          = var.cloudflare_account_id
  project_name        = each.key
  production_branch   = each.value.production_branch
  build_command       = each.value.build_command
  destination_dir     = each.value.destination_dir
  custom_domain       = each.value.custom_domain
  zone_id             = module.zone.zone_id
  zone_name           = module.zone.zone_name
  dns_ttl             = try(each.value.dns_ttl, 3600)
  dns_proxied         = try(each.value.dns_proxied, false)
  production_env_vars = try(each.value.production_env_vars, {})
  preview_env_vars    = try(each.value.preview_env_vars, {})
}
