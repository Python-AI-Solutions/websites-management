zone_name     = "pythonaisolutions.com"
gmail_enabled = true

# Replace placeholder values below with the authoritative DNS data once verified.
google_site_verification = "CPcm6QrtRNmu2LWDIyvBsooXrBHxtl6lRsyblr6CttM"

apex_records = {
  # Apex A records removed - now managed by Cloudflare Pages with CNAME flattening
  # The pythonaisolutions-website Pages project will handle both apex and www
  a = []

  txt = [
    # Site verification is managed by google-workspace-email module (google_site_verification var)
    # SPF is also managed by google-workspace-email module (gmail_enabled = true)
  ]
}

subdomain_records = {
  # Note: presentations and www subdomains are managed via pages_projects below
  # DNS CNAME records are automatically created by the Cloudflare Pages module

  # Cervical screening is now served by Cloudflare Pages (see pages_projects below).
  # The previous k8s-backed A records were removed to avoid DNS conflicts.

  "hih" = {
    a = [
      { value = "35.194.17.231", ttl = 86400 },
    ]
  }

  # GitHub Pages challenge records - these will need to be regenerated after DNS migration
  # GitHub will provide new challenge values when you verify the domain again
  # "_github-pages-challenge-leej3" = {
  #   txt = [
  #     { value = "36f3cde9c7c302988b87bfb8b2965a", ttl = 86400 },
  #   ]
  # }

  # "_github-pages-challenge-python-ai-solutions.presentations" = {
  #   txt = [
  #     { value = "36e88ec73472f3e0d4ee4d35ea3620", ttl = 86400 },
  #   ]
  # }
}

# Cloudflare Pages projects for static sites
# Each project automatically gets:
# - Pages project created in Cloudflare account
# - DNS CNAME record pointing custom domain to pages.dev URL
# - Custom domain configured in Pages project
pages_projects = {
  "hih-presentation" = {
    production_branch = "main"
    build_command     = "pixi run build"
    destination_dir   = "_site"
    custom_domain     = "presentations.pythonaisolutions.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }

  "company-handbook" = {
    production_branch = "main"
    build_command     = "pixi run build"
    destination_dir   = "_site"
    custom_domain     = "handbook.pythonaisolutions.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }

  "pythonaisolutions-website" = {
    production_branch = "main"
    build_command     = "npm run build"
    destination_dir   = "out"
    # Using custom_domains for both apex and www
    custom_domains = [
      "pythonaisolutions.com",
      "www.pythonaisolutions.com"
    ]
    dns_ttl     = 3600
    dns_proxied = false
  }

  "no-strings-resume" = {
    production_branch = "main"
    build_command     = "npm run build"
    destination_dir   = "dist"
    custom_domain     = "resume.pythonaisolutions.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }

  "agentic-cervical-screener" = {
    production_branch = "main"
    build_command     = "true"
    destination_dir   = "public"
    custom_domain     = "cervical-screening.pythonaisolutions.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }

  "entra-validation-app" = {
    production_branch = "main"
    build_command     = "true"
    destination_dir   = "public"
    custom_domain     = "entra-auth.pythonaisolutions.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }
}
