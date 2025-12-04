zone_name     = "example.com"
gmail_enabled = true

# Staging defaults mirror production; adjust records as staging infrastructure diverges.
google_site_verification = "TODO_fill_google_site_verification_token_if_required_for_staging"

apex_records = {
  a = [
    { value = "185.199.108.153" },
    { value = "185.199.109.153" },
    { value = "185.199.110.153" },
    { value = "185.199.111.153" },
  ]

  txt = [
    { value = "google-site-verification=TODO_replace_with_token" },
    { value = "MS=ms9071387??" },
    { value = "v=spf1 include:_spf.google.com ~all" },
  ]

  srv = [
    {
      service  = "_autodiscover"
      proto    = "_tcp"
      name     = "@"
      priority = 0
      weight   = 0
      port     = 443
      target   = "autodiscover.TODO-update"
    }
  ]
}

subdomain_records = {}
