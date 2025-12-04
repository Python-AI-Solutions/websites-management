terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "production" {
  metadata {
    name = "production"
    labels = {
      environment = "production"
    }
  }
}

resource "kubernetes_namespace" "staging" {
  metadata {
    name = "staging"
    labels = {
      environment = "staging"
    }
  }
}

locals {
  common_header_middlewares = [
    {
      name = "frontend-headers"
      response_headers = {
        "Cache-Control"          = "no-cache, no-store, must-revalidate"
        "X-Frame-Options"        = "DENY"
        "X-Content-Type-Options" = "nosniff"
        "Referrer-Policy"        = "strict-origin-when-cross-origin"
      }
    },
    {
      name = "api-headers"
      response_headers = {
        "Access-Control-Allow-Origin"  = "*"
        "Access-Control-Allow-Methods" = "GET, POST, PUT, DELETE, OPTIONS"
        "Access-Control-Allow-Headers" = "Content-Type, Authorization"
        "Cache-Control"                = "no-cache, no-store, must-revalidate"
      }
    },
    {
      name = "health-check-headers"
      response_headers = {
        "Cache-Control" = "no-cache, no-store, must-revalidate"
        "Pragma"        = "no-cache"
        "Expires"       = "0"
      }
    },
    {
      name = "static-assets-headers"
      response_headers = {
        "Cache-Control"               = "public, max-age=31536000"
        "Access-Control-Allow-Origin" = "*"
      }
    }
  ]
}

module "cervical_ai_viewer_prod" {
  source = "../../oauth2/modules/traefik_site"

  name                           = "cervical-ai-viewer"
  namespace                      = "production"
  host                           = "cervical-screening.example.com"
  root_route_backend             = "upstream"
  upstream_service_name          = "cervical-ai-viewer"
  upstream_service_port          = 80
  create_forward_auth_middleware = false
  tls_cert_resolver              = "letsencrypt"
  entrypoints                    = ["web", "websecure"]
  header_middlewares = [
    for middleware in local.common_header_middlewares : merge(middleware, {
      namespace      = "production"
      attach_to_root = false
    })
  ]

  depends_on = [kubernetes_namespace.production]
}

module "cervical_ai_viewer_staging" {
  source = "../../oauth2/modules/traefik_site"

  name                           = "cervical-ai-viewer-staging"
  namespace                      = "staging"
  host                           = "staging.cervical-screening.example.com"
  root_route_backend             = "upstream"
  upstream_service_name          = "cervical-ai-viewer"
  upstream_service_port          = 80
  create_forward_auth_middleware = false
  tls_cert_resolver              = "letsencrypt"
  entrypoints                    = ["web", "websecure"]
  header_middlewares = [
    for middleware in local.common_header_middlewares : merge(middleware, {
      namespace      = "staging"
      attach_to_root = false
    })
  ]

  depends_on = [kubernetes_namespace.staging]
}

module "mlflow" {
  source = "../../oauth2/modules/traefik_site"

  name               = "mlflow"
  namespace          = "mlflow"
  host               = "mlflow.cervical-screening.example.com"
  proxy_service_name = "oauth2-proxy"
  proxy_service_port = 80
  entrypoints        = ["web", "websecure"]
  tls_cert_resolver  = "letsencrypt"
}
