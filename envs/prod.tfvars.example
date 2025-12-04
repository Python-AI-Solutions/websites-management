zone_name     = "example.com"
gmail_enabled = true

# Replace placeholder values below with the authoritative DNS data once verified.
google_site_verification = "YOUR_VERIFICATION_TOKEN_HERE"

apex_records = {
  # Apex A records removed - now managed by Cloudflare Pages with CNAME flattening
  # The pythonaisolutions-website Pages project will handle both apex and www
  a = []

  txt = [
    { value = "google-site-verification=YOUR_VERIFICATION_TOKEN_HERE", ttl = 3600 },
    # SPF is now managed by google-workspace-email module (gmail_enabled = true)
  ]
}

subdomain_records = {
  # Note: presentations and www subdomains are managed via pages_projects below
  # DNS CNAME records are automatically created by the Cloudflare Pages module

  "cervical-screening" = {
    a = [
      { value = "203.0.113.1", ttl = 86400 },
    ]
  }

  "staging.cervical-screening" = {
    a = [
      { value = "203.0.113.1", ttl = 86400 },
    ]
  }

  "mlflow.cervical-screening" = {
    a = [
      { value = "203.0.113.1", ttl = 86400 },
    ]
  }

  "hih" = {
    a = [
      { value = "203.0.113.2", ttl = 86400 },
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
    custom_domain     = "presentations.example.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }

  "company-handbook" = {
    production_branch = "main"
    build_command     = "pixi run build"
    destination_dir   = "_site"
    custom_domain     = "handbook.example.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }

  "pythonaisolutions-website" = {
    production_branch = "main"
    build_command     = "npm run build"
    destination_dir   = "out"
    # Using custom_domains for both apex and www
    custom_domains = [
      "example.com",
      "www.example.com"
    ]
    dns_ttl     = 3600
    dns_proxied = false
  }

  "no-strings-resume" = {
    production_branch = "main"
    build_command     = "npm run build"
    destination_dir   = "dist"
    custom_domain     = "resume.example.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }
}
