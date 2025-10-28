terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Cloudflare Pages Project
resource "cloudflare_pages_project" "this" {
  account_id        = var.account_id
  name              = var.project_name
  production_branch = var.production_branch

  build_config {
    build_command   = var.build_command
    destination_dir = var.destination_dir
  }

  # Direct Upload deployment - GitHub Actions will handle the actual deployment
  deployment_configs {
    production {
      environment_variables = var.production_env_vars
    }

    preview {
      environment_variables = var.preview_env_vars
    }
  }
}

# Custom domain for the Pages project
resource "cloudflare_pages_domain" "custom_domain" {
  count = var.custom_domain != "" ? 1 : 0

  account_id   = var.account_id
  project_name = cloudflare_pages_project.this.name
  domain       = var.custom_domain
}

# DNS CNAME record pointing to Pages project
resource "cloudflare_record" "pages_cname" {
  count = var.custom_domain != "" && var.zone_id != "" ? 1 : 0

  zone_id = var.zone_id
  name    = trimsuffix(var.custom_domain, ".${var.zone_name}")
  type    = "CNAME"
  content = "${var.project_name}.pages.dev"
  ttl     = var.dns_ttl
  proxied = var.dns_proxied
}
