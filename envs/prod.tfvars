zone_name     = "pythonaisolutions.com"
gmail_enabled = false

# Replace placeholder values below with the authoritative DNS data once verified.
google_site_verification = "TODO_fill_google_site_verification_token"

apex_records = {
  a = [
    { value = "185.199.108.153", ttl = 86400 },
    { value = "185.199.109.153", ttl = 86400 },
    { value = "185.199.110.153", ttl = 86400 },
    { value = "185.199.111.153", ttl = 86400 },
  ]

  txt = [
    { value = "google-site-verification=TODO_replace_with_token", ttl = 3600 },
    # SPF will be managed by google-workspace-email module when gmail_enabled = true
    # Keeping it here temporarily until you're ready to enable Google Workspace
    { value = "v=spf1 include:_spf.google.com ~all", ttl = 3600 },
  ]
}

subdomain_records = {
  "www" = {
    cname = [
      { value = "leej3.github.io", ttl = 86400, proxied = false },
    ]
  }

  "presentations" = {
    cname = [
      { value = "hih-presentation.pages.dev", ttl = 3600, proxied = false },
    ]
  }

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
  "_github-pages-challenge-leej3" = {
    txt = [
      { value = "36f3cde9c7c302988b87bfb8b2965a", ttl = 86400 },
    ]
  }

  "_github-pages-challenge-python-ai-solutions.presentations" = {
    txt = [
      { value = "36e88ec73472f3e0d4ee4d35ea3620", ttl = 86400 },
    ]
  }
}
