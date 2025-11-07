output "proxies" {
  description = "Information about each configured oauth2-proxy instance."
  value = {
    for name, mod in module.oauth2_proxy : name => {
      namespace       = mod.namespace
      deployment_name = mod.deployment_name
      service_name    = mod.service_name
      secret_name     = mod.secret_name
      redirect_url    = mod.redirect_url
      upstreams       = mod.upstreams
      args            = mod.args
      cookie_secret   = mod.cookie_secret
    }
  }
  sensitive = true
}

output "traefik_sites" {
  description = "Details for each Traefik site configured via the companion module."
  value = {
    for name, mod in module.traefik_site : name => {
      host                         = mod.host
      ingress_route_name           = mod.ingress_route_name
      forward_auth_middleware_name = mod.forward_auth_middleware_name
    }
  }
}
