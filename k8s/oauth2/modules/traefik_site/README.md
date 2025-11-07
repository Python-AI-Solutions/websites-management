# traefik_site module

Defines Traefik `IngressRoute` (and optional middleware resources) for applications that may or may not sit behind oauth2-proxy. The module can:

- Route traffic directly to oauth2-proxy (`root_route_backend = "proxy"`)
- Send traffic straight to your upstream service while still leveraging forward-auth against oauth2-proxy (`root_route_backend = "upstream"`)
- Skip oauth2 entirely by omitting `proxy_service_name` and just manage the IngressRoute + header middlewares

## Key Features

- `/oauth2` path is generated automatically when an oauth2-proxy Service is provided
- Catch-all route can target the proxy or your upstream app
- Optional Traefik forward-auth middleware generated automatically when protecting an upstream service
- Header middlewares (custom request/response headers) can be declared and optionally attached to the root route
- TLS can be managed via existing secrets *or* a Traefik `certResolver`

## Inputs (highlights)

| Name | Description | Default |
|------|-------------|---------|
| `name` | Logical name/prefix | – |
| `namespace` | Namespace for Traefik CRDs | – |
| `host` | Hostname to match | – |
| `proxy_service_name` | Service name for oauth2-proxy (optional) | `null` |
| `proxy_service_port` | Port for oauth2-proxy Service | `80` |
| `root_route_backend` | `proxy` (default) or `upstream` | `proxy` |
| `upstream_service_name` | Upstream Service (required when backend = `upstream`) | `null` |
| `upstream_service_port` | Upstream Service port | `null` |
| `entrypoints` | Traefik entrypoints | `["web", "websecure"]` |
| `tls_secret_name` | Optional TLS secret | `null` |
| `tls_cert_resolver` | Optional Traefik certResolver name | `null` |
| `create_forward_auth_middleware` | Emit forward-auth middleware | `true` |
| `forward_auth_path` | oauth2-proxy auth endpoint | `/oauth2/auth` |
| `forward_auth_additional_headers` | Headers passed upstream | see defaults |
| `header_middlewares` | Header middleware resources to generate | `[]` |
| `extra_root_middlewares` | Additional middlewares to attach | `[]` |

**Note:** When you set `root_route_backend = "proxy"`, supply `proxy_service_name`. When you set `root_route_backend = "upstream"`, provide both `upstream_service_name` and `upstream_service_port`.

## Outputs

- `ingress_route_name` – Name of the generated IngressRoute
- `forward_auth_middleware_name` – Name of the forward-auth middleware (if used)
- `host` – Host that is protected
- `header_middlewares` – List of header middlewares created by the module

## Example

```hcl
module "mlflow_traefik" {
  source = "../modules/traefik_site"

  name                = "mlflow"
  namespace           = "mlflow"
  host                = "mlflow.example.com"
  proxy_service_name  = module.mlflow_oauth_proxy.service_name
  proxy_service_port  = 80
  tls_secret_name     = "mlflow-tls"
  root_route_backend  = "proxy" # Traefik routes everything to oauth2-proxy
}

# Direct app exposure with forward-auth
module "grafana_traefik" {
  source = "../modules/traefik_site"

  name                   = "grafana"
  namespace              = "monitoring"
  host                   = "grafana.example.com"
  proxy_service_name     = module.grafana_auth.service_name
  proxy_service_port     = 80
  root_route_backend     = "upstream"
  upstream_service_name  = "grafana"
  upstream_service_port  = 3000
  tls_cert_resolver      = "letsencrypt"
  header_middlewares = [{
    name             = "grafana-headers"
    response_headers = {
      "X-Frame-Options"       = "DENY"
      "X-Content-Type-Options" = "nosniff"
    }
  }]
}

# Traefik-exposed service without oauth2-proxy
module "public_site" {
  source = "../modules/traefik_site"

  name          = "public-site"
  namespace     = "production"
  host          = "example.com"
  root_route_backend   = "upstream"
  upstream_service_name = "public-app"
  upstream_service_port = 8080
  tls_cert_resolver     = "letsencrypt"
  header_middlewares = [
    {
      name             = "public-security"
      response_headers = {
        "Referrer-Policy" = "strict-origin-when-cross-origin"
        "Cache-Control"   = "no-cache, no-store, must-revalidate"
      }
    }
  ]
}
```
