locals {
  sites = var.sites
}

module "oauth2_proxy" {
  source   = "./modules/oauth2_proxy"
  for_each = local.sites

  name                     = each.key
  namespace                = each.value.namespace
  create_namespace         = lookup(each.value, "create_namespace", true)
  client_id                = each.value.client_id
  client_secret            = each.value.client_secret
  desktop_client_id        = lookup(each.value, "desktop_client_id", null)
  cookie_secret            = lookup(each.value, "cookie_secret", null)
  redirect_url             = each.value.redirect_url
  upstreams                = each.value.upstreams
  email_domains            = lookup(each.value, "email_domains", [])
  allowed_emails           = lookup(each.value, "allowed_emails", [])
  extra_args               = lookup(each.value, "extra_args", [])
  image                    = lookup(each.value, "image", "quay.io/oauth2-proxy/oauth2-proxy:v7.6.0")
  replicas                 = lookup(each.value, "replicas", 2)
  listen_port              = lookup(each.value, "listen_port", 4180)
  cookie_refresh           = lookup(each.value, "cookie_refresh", "1h")
  cookie_secure            = lookup(each.value, "cookie_secure", true)
  skip_provider_button     = lookup(each.value, "skip_provider_button", true)
  skip_jwt_bearer_tokens   = lookup(each.value, "skip_jwt_bearer_tokens", true)
  pass_access_token        = lookup(each.value, "pass_access_token", true)
  pass_user_headers        = lookup(each.value, "pass_user_headers", true)
  set_authorization_header = lookup(each.value, "set_authorization_header", true)
  set_xauthrequest         = lookup(each.value, "set_xauthrequest", true)
  service_name             = lookup(each.value, "service_name", null)
  service_type             = lookup(each.value, "service_type", "ClusterIP")
  service_port             = lookup(each.value, "service_port", 80)
  service_annotations      = lookup(each.value, "service_annotations", {})
  deployment_name          = lookup(each.value, "deployment_name", null)
  secret_name              = lookup(each.value, "secret_name", null)
  pod_annotations          = lookup(each.value, "pod_annotations", {})
  pod_labels               = lookup(each.value, "pod_labels", {})
  selector_labels          = lookup(each.value, "selector_labels", {})
  extra_env                = lookup(each.value, "extra_env", {})
  extra_secret_data        = lookup(each.value, "extra_secret_data", {})
  resources                = lookup(each.value, "resources", null)
  node_selector            = lookup(each.value, "node_selector", {})
  tolerations              = lookup(each.value, "tolerations", [])
}

module "traefik_site" {
  source   = "./modules/traefik_site"
  for_each = var.traefik_sites

  name                              = each.key
  namespace                         = each.value.namespace
  host                              = each.value.host
  proxy_service_name                = each.value.proxy_service_name
  proxy_service_port                = lookup(each.value, "proxy_service_port", 80)
  root_route_backend                = lookup(each.value, "root_route_backend", "proxy")
  upstream_service_name             = lookup(each.value, "upstream_service_name", null)
  upstream_service_port             = lookup(each.value, "upstream_service_port", null)
  entrypoints                       = lookup(each.value, "entrypoints", ["web", "websecure"])
  tls_secret_name                   = lookup(each.value, "tls_secret_name", null)
  ingress_route_name                = lookup(each.value, "ingress_route_name", null)
  create_forward_auth_middleware    = lookup(each.value, "create_forward_auth_middleware", true)
  forward_auth_middleware_name      = lookup(each.value, "forward_auth_middleware_name", null)
  forward_auth_middleware_namespace = lookup(each.value, "forward_auth_middleware_namespace", null)
  forward_auth_path                 = lookup(each.value, "forward_auth_path", "/oauth2/auth")
  forward_auth_trust_forward_header = lookup(each.value, "forward_auth_trust_forward_header", true)
  forward_auth_additional_headers = lookup(each.value, "forward_auth_additional_headers", [
    "X-Auth-Request-Email",
    "X-Auth-Request-User",
    "Authorization"
  ])
  extra_root_middlewares = lookup(each.value, "extra_root_middlewares", [])
}
