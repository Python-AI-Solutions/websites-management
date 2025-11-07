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

data "kubernetes_secret" "oauth2_existing" {
  count = var.use_existing_oauth2_secret ? 1 : 0

  metadata {
    name      = var.oauth2_secret_name
    namespace = var.namespace
  }
}

data "kubernetes_secret" "postgres_existing" {
  count = var.use_existing_postgres_secret ? 1 : 0

  metadata {
    name      = var.postgres_secret_name
    namespace = var.namespace
  }
}

locals {
  oauth2_existing_secret   = var.use_existing_oauth2_secret ? data.kubernetes_secret.oauth2_existing[0] : null
  postgres_existing_secret = var.use_existing_postgres_secret ? data.kubernetes_secret.postgres_existing[0] : null

  oauth2_existing_secret_data = var.use_existing_oauth2_secret ? local.oauth2_existing_secret.data : {}
  postgres_existing_secret_data = var.use_existing_postgres_secret ? local.postgres_existing_secret.data : {}

  oauth2_client_id_step1 = var.use_existing_oauth2_secret ? try(base64decode(nonsensitive(local.oauth2_existing_secret_data.client_id)), local.oauth2_existing_secret_data.client_id) : null
  oauth2_client_id_step2 = var.use_existing_oauth2_secret ? try(base64decode(local.oauth2_client_id_step1), local.oauth2_client_id_step1) : null
  oauth2_client_id_step3 = var.use_existing_oauth2_secret ? try(base64decode(local.oauth2_client_id_step2), local.oauth2_client_id_step2) : null
  oauth2_client_id_plain = coalesce(var.oauth2_client_id, var.use_existing_oauth2_secret ? local.oauth2_client_id_step3 : null)

  oauth2_client_secret_step1 = var.use_existing_oauth2_secret ? try(base64decode(nonsensitive(local.oauth2_existing_secret_data.client_secret)), local.oauth2_existing_secret_data.client_secret) : null
  oauth2_client_secret_step2 = var.use_existing_oauth2_secret ? try(base64decode(local.oauth2_client_secret_step1), local.oauth2_client_secret_step1) : null
  oauth2_client_secret_step3 = var.use_existing_oauth2_secret ? try(base64decode(local.oauth2_client_secret_step2), local.oauth2_client_secret_step2) : null
  oauth2_client_secret_plain = coalesce(var.oauth2_client_secret, var.use_existing_oauth2_secret ? local.oauth2_client_secret_step3 : null)

  oauth2_cookie_secret_step1 = var.use_existing_oauth2_secret ? try(base64decode(nonsensitive(local.oauth2_existing_secret_data.cookie_secret)), local.oauth2_existing_secret_data.cookie_secret) : null
  oauth2_cookie_secret_step2 = var.use_existing_oauth2_secret ? try(base64decode(local.oauth2_cookie_secret_step1), local.oauth2_cookie_secret_step1) : null
  oauth2_cookie_secret_step3 = var.use_existing_oauth2_secret ? try(base64decode(local.oauth2_cookie_secret_step2), local.oauth2_cookie_secret_step2) : null
  oauth2_cookie_secret_plain = coalesce(var.oauth2_cookie_secret, var.use_existing_oauth2_secret ? local.oauth2_cookie_secret_step3 : null)

  oauth2_desktop_client_id_step1 = (var.use_existing_oauth2_secret && lookup(local.oauth2_existing_secret_data, "desktop_client_id", null) != null) ? try(base64decode(nonsensitive(local.oauth2_existing_secret_data.desktop_client_id)), local.oauth2_existing_secret_data.desktop_client_id) : null
  oauth2_desktop_client_id_step2 = var.use_existing_oauth2_secret ? try(base64decode(local.oauth2_desktop_client_id_step1), local.oauth2_desktop_client_id_step1) : null
  oauth2_desktop_client_id_step3 = var.use_existing_oauth2_secret ? try(base64decode(local.oauth2_desktop_client_id_step2), local.oauth2_desktop_client_id_step2) : null
  oauth2_desktop_client_id_plain = coalesce(var.oauth2_desktop_client_id, var.use_existing_oauth2_secret ? local.oauth2_desktop_client_id_step3 : null)

  postgres_user_step1 = var.use_existing_postgres_secret ? try(base64decode(nonsensitive(local.postgres_existing_secret_data.POSTGRES_USER)), local.postgres_existing_secret_data.POSTGRES_USER) : null
  postgres_user_step2 = var.use_existing_postgres_secret ? try(base64decode(local.postgres_user_step1), local.postgres_user_step1) : null
  postgres_user_step3 = var.use_existing_postgres_secret ? try(base64decode(local.postgres_user_step2), local.postgres_user_step2) : null
  postgres_user_plain = coalesce(var.postgres_user, var.use_existing_postgres_secret ? local.postgres_user_step3 : null)

  postgres_password_step1 = var.use_existing_postgres_secret ? try(base64decode(nonsensitive(local.postgres_existing_secret_data.POSTGRES_PASSWORD)), local.postgres_existing_secret_data.POSTGRES_PASSWORD) : null
  postgres_password_step2 = var.use_existing_postgres_secret ? try(base64decode(local.postgres_password_step1), local.postgres_password_step1) : null
  postgres_password_step3 = var.use_existing_postgres_secret ? try(base64decode(local.postgres_password_step2), local.postgres_password_step2) : null
  postgres_password_plain = coalesce(var.postgres_password, var.use_existing_postgres_secret ? local.postgres_password_step3 : null)

  postgres_database_step1 = var.use_existing_postgres_secret ? try(base64decode(nonsensitive(local.postgres_existing_secret_data.POSTGRES_DB)), local.postgres_existing_secret_data.POSTGRES_DB) : null
  postgres_database_step2 = var.use_existing_postgres_secret ? try(base64decode(local.postgres_database_step1), local.postgres_database_step1) : null
  postgres_database_step3 = var.use_existing_postgres_secret ? try(base64decode(local.postgres_database_step2), local.postgres_database_step2) : null
  postgres_database_plain = coalesce(var.postgres_database, var.use_existing_postgres_secret ? local.postgres_database_step3 : null)

  postgres_secret_data = {
    POSTGRES_USER     = base64encode(local.postgres_user_plain)
    POSTGRES_PASSWORD = base64encode(local.postgres_password_plain)
    POSTGRES_DB       = base64encode(local.postgres_database_plain)
  }

  oauth2_secret_extra_data_plain = local.oauth2_desktop_client_id_plain != null ? {
    desktop_client_id = local.oauth2_desktop_client_id_plain
  } : {}
}

resource "kubernetes_namespace" "mlflow" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

resource "kubernetes_service_account" "mlflow" {
  metadata {
    name      = "mlflow-sa"
    namespace = var.namespace
  }

  depends_on = [kubernetes_namespace.mlflow]
}

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = var.postgres_secret_name
    namespace = var.namespace
  }

  data = local.postgres_secret_data

  depends_on = [kubernetes_namespace.mlflow]
}

resource "kubernetes_persistent_volume_claim" "mlflow_data" {
  metadata {
    name      = "mlflow-data"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.mlflow_storage_request
      }
    }

    storage_class_name = var.storage_class_name
  }

  depends_on = [kubernetes_namespace.mlflow]

  lifecycle {
    prevent_destroy = true
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_data" {
  metadata {
    name      = "postgres-data"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.postgres_storage_request
      }
    }

    storage_class_name = var.storage_class_name
  }

  depends_on = [kubernetes_namespace.mlflow]

  lifecycle {
    prevent_destroy = true
  }
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
    labels = {
      app = "postgres"
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = 0
        max_unavailable = 1
      }
    }

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = var.postgres_image

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = var.postgres_secret_name
                key  = "POSTGRES_USER"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.postgres_secret_name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = var.postgres_secret_name
                key  = "POSTGRES_DB"
              }
            }
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          port {
            name           = "postgres"
            container_port = 5432
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", local.postgres_user_plain]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", local.postgres_user_plain]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
          }

          resources {
            limits = {
              cpu    = "1"
              memory = "2Gi"
            }
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "postgres-data"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "postgres-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_data.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim.postgres_data,
    kubernetes_secret.postgres,
    kubernetes_namespace.mlflow
  ]
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = var.namespace
    labels = {
      app = "postgres"
    }
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
    }
  }

  depends_on = [kubernetes_namespace.mlflow]
}

resource "kubernetes_deployment" "mlflow" {
  metadata {
    name      = "mlflow"
    namespace = var.namespace
    labels = {
      app = "mlflow"
    }
  }

  spec {
    replicas = var.mlflow_replicas

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = 0
        max_unavailable = 1
      }
    }

    selector {
      match_labels = {
        app = "mlflow"
      }
    }

    template {
      metadata {
        labels = {
          app = "mlflow"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.mlflow.metadata[0].name

        container {
          name  = "mlflow"
          image = var.mlflow_image
          args  = ["bash", "-lc", "pip install psycopg2-binary && mlflow server --host 0.0.0.0 --port 5000 --backend-store-uri postgresql://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@postgres:5432/$(POSTGRES_DB) --default-artifact-root ${var.artifact_root} --serve-artifacts --allowed-hosts ${var.mlflow_host}"]

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = var.postgres_secret_name
                key  = "POSTGRES_USER"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.postgres_secret_name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = var.postgres_secret_name
                key  = "POSTGRES_DB"
              }
            }
          }

          env {
            name  = "GOOGLE_APPLICATION_CREDENTIALS"
            value = "${var.gcs_credentials_mount_path}/key.json"
          }

          port {
            name           = "http"
            container_port = 5000
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 5000
              http_header {
                name  = "Host"
                value = var.mlflow_host
              }
            }
            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 1
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 5000
              http_header {
                name  = "Host"
                value = var.mlflow_host
              }
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 1
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "mlflow-data"
            mount_path = "/mlflow"
          }

          volume_mount {
            name       = "gcs-credentials"
            mount_path = var.gcs_credentials_mount_path
            read_only  = true
          }
        }

        volume {
          name = "mlflow-data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mlflow_data.metadata[0].name
          }
        }

        volume {
          name = "gcs-credentials"

          secret {
            secret_name = var.gcs_credentials_secret_name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_persistent_volume_claim.mlflow_data,
    kubernetes_service_account.mlflow,
    kubernetes_secret.postgres,
    kubernetes_namespace.mlflow
  ]
}

resource "kubernetes_service" "mlflow" {
  metadata {
    name      = "mlflow"
    namespace = var.namespace
    labels = {
      app = "mlflow"
    }
    annotations = {
      "cloud.google.com/neg" = "{\"ingress\":true}"
    }
  }

  spec {
    selector = {
      app = "mlflow"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 5000
    }
  }

  depends_on = [kubernetes_namespace.mlflow]
}

module "oauth2_proxy" {
  source = "../../oauth2/modules/oauth2_proxy"

  name             = "mlflow"
  namespace        = var.namespace
  create_namespace = false

  client_id         = local.oauth2_client_id_plain
  client_secret     = local.oauth2_client_secret_plain
  cookie_secret     = local.oauth2_cookie_secret_plain
  desktop_client_id = local.oauth2_desktop_client_id_plain

  redirect_url = "https://${var.mlflow_host}/oauth2/callback"
  upstreams    = ["http://mlflow.${var.namespace}.svc.cluster.local"]

  email_domains  = var.email_domains
  allowed_emails = var.allowed_emails

  replicas     = var.oauth2_replicas
  listen_port  = 4180
  service_name = "oauth2-proxy"
  service_port = 80
  service_annotations = {
    "cloud.google.com/neg" = "{\"ingress\":true}"
  }

  deployment_name = "oauth2-proxy"
  secret_name     = var.oauth2_secret_name

  selector_labels = {
    app = "oauth2-proxy"
  }

  pod_labels = {
    app       = "oauth2-proxy"
    component = "oauth2-proxy"
  }

  extra_secret_data = local.oauth2_secret_extra_data_plain

  depends_on = [kubernetes_namespace.mlflow]
}
