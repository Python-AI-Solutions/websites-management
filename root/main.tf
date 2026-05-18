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
  custom_domains      = try(each.value.custom_domains, [])
  zone_id             = module.zone.zone_id
  zone_name           = module.zone.zone_name
  dns_ttl             = try(each.value.dns_ttl, 3600)
  dns_proxied         = try(each.value.dns_proxied, false)
  production_env_vars = try(each.value.production_env_vars, {})
  preview_env_vars    = try(each.value.preview_env_vars, {})
}

module "additional_zones" {
  for_each = var.additional_zones
  source   = "../modules/cloudflare-zone"

  zone_name  = each.key
  account_id = var.cloudflare_account_id
}

module "additional_zone_records" {
  for_each = var.additional_zones
  source   = "../modules/cloudflare-records"

  zone_id         = module.additional_zones[each.key].zone_id
  zone_name       = module.additional_zones[each.key].zone_name
  records         = each.value.records
  default_ttl     = 3600
  default_proxied = false
}

locals {
  additional_pages_domains = {
    for item in flatten([
      for group_key, group in var.additional_pages_domains : [
        for domain in group.domains : {
          key          = "${group_key}:${domain}"
          zone_name    = group.zone_name
          project_name = group.project_name
          domain       = domain
          dns_ttl      = group.dns_ttl
          dns_proxied  = group.dns_proxied
        }
      ]
    ]) : item.key => item
  }
}

resource "cloudflare_pages_domain" "additional_pages_domains" {
  for_each = local.additional_pages_domains

  account_id = var.cloudflare_account_id
  project_name = contains(keys(module.pages_projects), each.value.project_name) ? (
    module.pages_projects[each.value.project_name].project_name
  ) : each.value.project_name
  domain = each.value.domain

  depends_on = [module.additional_zones]
}

resource "cloudflare_record" "additional_pages_cnames" {
  for_each = local.additional_pages_domains

  zone_id = module.additional_zones[each.value.zone_name].zone_id
  name = each.value.domain == each.value.zone_name ? (
    each.value.zone_name
  ) : trimsuffix(each.value.domain, ".${each.value.zone_name}")
  type    = "CNAME"
  content = "${each.value.project_name}.pages.dev"
  ttl     = each.value.dns_proxied ? 1 : each.value.dns_ttl
  proxied = each.value.dns_proxied
}
