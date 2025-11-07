locals {
  namespace        = var.namespace
  deployment_name  = coalesce(var.deployment_name, "${var.name}-oauth2-proxy")
  service_name     = coalesce(var.service_name, "${var.name}-oauth2-proxy")
  secret_name      = coalesce(var.secret_name, "${var.name}-oauth2-proxy-secret")
  selector_labels  = merge({ "app" = var.name }, var.selector_labels)
  pod_labels       = merge(local.selector_labels, { "component" = "oauth2-proxy" }, var.pod_labels)
  generated_secret = var.cookie_secret != null ? var.cookie_secret : base64encode(random_password.cookie_secret[0].result)

  base_args = [
    "--provider=google",
    "--redirect-url=${var.redirect_url}",
    "--http-address=0.0.0.0:${var.listen_port}",
    "--cookie-secure=${var.cookie_secure ? "true" : "false"}",
    "--cookie-refresh=${var.cookie_refresh}",
    "--set-authorization-header=${var.set_authorization_header ? "true" : "false"}",
    "--set-xauthrequest=${var.set_xauthrequest ? "true" : "false"}",
    "--pass-access-token=${var.pass_access_token ? "true" : "false"}",
    "--pass-user-headers=${var.pass_user_headers ? "true" : "false"}",
    "--skip-provider-button=${var.skip_provider_button ? "true" : "false"}",
    "--skip-jwt-bearer-tokens=${var.skip_jwt_bearer_tokens ? "true" : "false"}"
  ]

  upstream_args        = [for upstream in var.upstreams : "--upstream=${upstream}"]
  email_domain_args    = [for domain in var.email_domains : "--email-domain=${domain}"]
  allowed_email_args   = [for email in var.allowed_emails : "--allowed-email=${email}"]
  desktop_client_args  = var.desktop_client_id != null ? ["--extra-jwt-issuers=https://accounts.google.com=${var.desktop_client_id}"] : []
  all_args             = distinct(concat(local.base_args, local.upstream_args, local.email_domain_args, local.allowed_email_args, local.desktop_client_args, var.extra_args))

  secret_string_data = merge({
    client_id     = var.client_id,
    client_secret = var.client_secret,
    cookie_secret = local.generated_secret
  }, var.desktop_client_id != null ? { desktop_client_id = var.desktop_client_id } : {}, var.extra_secret_data)

  secret_data = {
    for key, value in local.secret_string_data :
    key => base64encode(value)
  }
}

resource "kubernetes_namespace" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = local.namespace
  }
}

resource "random_password" "cookie_secret" {
  count   = var.cookie_secret == null ? 1 : 0
  length  = 32
  special = false
}

resource "kubernetes_secret" "oauth2" {
  metadata {
    name      = local.secret_name
    namespace = local.namespace
  }

  type = "Opaque"
  data = local.secret_data

  depends_on = [kubernetes_namespace.this]
}

resource "kubernetes_deployment" "oauth2" {
  metadata {
    name      = local.deployment_name
    namespace = local.namespace
    labels    = local.selector_labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = local.selector_labels
    }

    template {
      metadata {
        labels      = local.pod_labels
        annotations = var.pod_annotations
      }

      spec {
        node_selector = var.node_selector

        dynamic "toleration" {
          for_each = var.tolerations
          content {
            key               = toleration.value.key
            operator          = toleration.value.operator
            value             = lookup(toleration.value, "value", null)
            effect            = lookup(toleration.value, "effect", null)
            toleration_seconds = lookup(toleration.value, "toleration_seconds", null)
          }
        }

        container {
          name  = "oauth2-proxy"
          image = var.image
          args  = local.all_args

          env {
            name = "OAUTH2_PROXY_CLIENT_ID"
            value_from {
              secret_key_ref {
                name = local.secret_name
                key  = "client_id"
              }
            }
          }

          env {
            name = "OAUTH2_PROXY_CLIENT_SECRET"
            value_from {
              secret_key_ref {
                name = local.secret_name
                key  = "client_secret"
              }
            }
          }

          env {
            name = "OAUTH2_PROXY_COOKIE_SECRET"
            value_from {
              secret_key_ref {
                name = local.secret_name
                key  = "cookie_secret"
              }
            }
          }

          dynamic "env" {
            for_each = var.extra_env
            content {
              name  = env.key
              value = env.value
            }
          }

          port {
            container_port = var.listen_port
            name           = "http"
          }

          readiness_probe {
            http_get {
              path = "/ping"
              port = var.listen_port
            }
            initial_delay_seconds = 3
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/ping"
              port = var.listen_port
            }
            initial_delay_seconds = 10
            period_seconds        = 20
          }

          dynamic "resources" {
            for_each = var.resources == null ? [] : [var.resources]
            content {
              limits   = lookup(resources.value, "limits", null)
              requests = lookup(resources.value, "requests", null)
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.oauth2]
}

resource "kubernetes_service" "oauth2" {
  metadata {
    name        = local.service_name
    namespace   = local.namespace
    labels      = local.selector_labels
    annotations = var.service_annotations
  }

  spec {
    type = var.service_type

    selector = local.selector_labels

    port {
      name        = "http"
      port        = var.service_port
      target_port = var.listen_port
    }
  }
}
