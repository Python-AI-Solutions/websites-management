zone_name     = "pythonaisolutions.com"
gmail_enabled = false

# Replace placeholder values below with the authoritative DNS data once verified.
google_site_verification = "CPcm6QrtRNmu2LWDIyvBsooXrBHxtl6lRsyblr6CttM"

apex_records = {
  a = [
    { value = "185.199.108.153", ttl = 86400 },
    { value = "185.199.109.153", ttl = 86400 },
    { value = "185.199.110.153", ttl = 86400 },
    { value = "185.199.111.153", ttl = 86400 },
  ]

  txt = [
    { value = "google-site-verification=CPcm6QrtRNmu2LWDIyvBsooXrBHxtl6lRsyblr6CttM", ttl = 3600 },
    # SPF will be managed by google-workspace-email module when gmail_enabled = true
    # Keeping it here temporarily until you're ready to enable Google Workspace
    { value = "v=spf1 include:_spf.google.com ~all", ttl = 3600 },
  ]
}

subdomain_records = {
  # Note: presentations and www subdomains are managed via pages_projects below
  # DNS CNAME records are automatically created by the Cloudflare Pages module

  "cervical-screening" = {
    a = [
      { value = "104.198.164.116", ttl = 86400 },
    ]
  }

  "staging.cervical-screening" = {
    a = [
      { value = "104.198.164.116", ttl = 86400 },
    ]
  }

  "mlflow.cervical-screening" = {
    a = [
      { value = "104.198.164.116", ttl = 86400 },
    ]
  }

  "hih" = {
    a = [
      { value = "35.194.17.231", ttl = 86400 },
    ]
  }

  "osm" = {
    a = [
      { value = "18.214.163.6", ttl = 86400 },
    ]
  }

  "osm-dashboard" = {
    a = [
      { value = "18.214.163.6", ttl = 86400 },
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
    custom_domain     = "www.pythonaisolutions.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }

  "no-strings-resume" = {
    production_branch = "main"
    build_command     = "npm run build"
    destination_dir   = "dist"
    custom_domain     = "resume.pythonaisolutions.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }
}
