variable "project_id" {
  description = "Optional GCP project identifier; only used if callers enable Google provider in this stack."
  type        = string
  default     = null
}

variable "region" {
  description = "Optional default region; kept for parity with other stacks."
  type        = string
  default     = null
}

variable "sites" {
  description = "Map of oauth2-proxy site configurations."
  type = map(object({
    namespace                = string
    client_id                = string
    client_secret            = string
    redirect_url             = string
    upstreams                = list(string)
    create_namespace         = optional(bool, true)
    desktop_client_id        = optional(string)
    cookie_secret            = optional(string)
    email_domains            = optional(list(string), [])
    allowed_emails           = optional(list(string), [])
    extra_args               = optional(list(string), [])
    image                    = optional(string, "quay.io/oauth2-proxy/oauth2-proxy:v7.6.0")
    replicas                 = optional(number, 2)
    listen_port              = optional(number, 4180)
    cookie_refresh           = optional(string, "1h")
    cookie_secure            = optional(bool, true)
    skip_provider_button     = optional(bool, true)
    skip_jwt_bearer_tokens   = optional(bool, true)
    pass_access_token        = optional(bool, true)
    pass_user_headers        = optional(bool, true)
    set_authorization_header = optional(bool, true)
    set_xauthrequest         = optional(bool, true)
    service_name             = optional(string)
    service_type             = optional(string, "ClusterIP")
    service_port             = optional(number, 80)
    service_annotations      = optional(map(string), {})
    deployment_name          = optional(string)
    secret_name              = optional(string)
    pod_annotations          = optional(map(string), {})
    pod_labels               = optional(map(string), {})
    selector_labels          = optional(map(string), {})
    extra_env                = optional(map(string), {})
    extra_secret_data        = optional(map(string), {})
    resources = optional(object({
      limits   = optional(map(string))
      requests = optional(map(string))
    }))
    node_selector = optional(map(string), {})
    tolerations = optional(list(object({
      key                = string
      operator           = string
      value              = optional(string)
      effect             = optional(string)
      toleration_seconds = optional(number)
    })), [])
  }))
  default = {}
}

variable "traefik_sites" {
  description = "Map of Traefik ingress configurations keyed by logical site name."
  type = map(object({
    namespace                         = string
    host                              = string
    proxy_service_name                = string
    proxy_service_port                = optional(number, 80)
    root_route_backend                = optional(string, "proxy")
    upstream_service_name             = optional(string)
    upstream_service_port             = optional(number)
    entrypoints                       = optional(list(string), ["web", "websecure"])
    tls_secret_name                   = optional(string)
    ingress_route_name                = optional(string)
    create_forward_auth_middleware    = optional(bool, true)
    forward_auth_middleware_name      = optional(string)
    forward_auth_middleware_namespace = optional(string)
    forward_auth_path                 = optional(string, "/oauth2/auth")
    forward_auth_trust_forward_header = optional(bool, true)
    forward_auth_additional_headers = optional(list(string), [
      "X-Auth-Request-Email",
      "X-Auth-Request-User",
      "Authorization"
    ])
    extra_root_middlewares = optional(list(object({
      name      = string
      namespace = optional(string)
    })), [])
  }))
  default = {}
}
