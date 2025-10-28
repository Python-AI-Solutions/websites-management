zone_name     = "pythonaisolutions.com"
gmail_enabled = true

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
    { value = "MS=ms9071387??", ttl = 3600 }, # TODO confirm Microsoft verification string
    { value = "v=spf1 include:_spf.google.com ~all", ttl = 3600 },
  ]

  srv = [
    {
      service  = "_autodiscover"
      proto    = "_tcp"
      name     = "@"
      priority = 0
      weight   = 0
      port     = 443
      target   = "autodiscover.reg365.net"
      ttl      = 86400
    }
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
      { value = "hih-presentation.TODO-update", ttl = 3600, proxied = false },
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

  "autoconfig" = {
    cname = [
      { value = "autoconfig.TODO-complete", ttl = 86400 },
    ]
  }

  "imap" = {
    cname = [
      { value = "imap.reg365.net", ttl = 86400 },
    ]
  }

  "pop3" = {
    cname = [
      { value = "pop3.reg365.net", ttl = 86400 },
    ]
  }

  "cpanel" = {
    ns = [
      { value = "ns0.reg365.net", ttl = 86400 },
      { value = "ns1.reg365.net", ttl = 86400 },
      { value = "ns2.reg365.net", ttl = 86400 },
    ]
  }

  "_github-pages-challenge-1" = {
    txt = [
      { value = "36f3cde9c7c302TODO-complete", ttl = 86400 },
    ]
  }

  "_github-pages-challenge-2" = {
    txt = [
      { value = "36e88ec73472f3TODO-complete", ttl = 86400 },
    ]
  }
}
