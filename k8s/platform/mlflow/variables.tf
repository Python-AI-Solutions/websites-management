variable "namespace" {
  description = "Namespace used for all MLflow resources."
  type        = string
  default     = "mlflow"
}

variable "create_namespace" {
  description = "Whether this stack should create the namespace (disable if it already exists or is managed elsewhere)."
  type        = bool
  default     = true
}

variable "mlflow_host" {
  description = "External hostname serving the MLflow UI."
  type        = string
  default     = "mlflow.cervical-screening.pythonaisolutions.com"
}

variable "artifact_root" {
  description = "GS URI where MLflow stores artifacts."
  type        = string
  default     = "gs://pythonaisolutions-mlflow-artifacts/mlflow"
}

variable "mlflow_image" {
  description = "Container image for the MLflow server."
  type        = string
  default     = "ghcr.io/mlflow/mlflow:latest"
}

variable "mlflow_replicas" {
  description = "Number of MLflow pods."
  type        = number
  default     = 1
}

variable "gcs_credentials_secret_name" {
  description = "Secret containing the GCS service account key used for artifact access."
  type        = string
  default     = "gcs-credentials"
}

variable "gcs_credentials_mount_path" {
  description = "Filesystem path where the GCS credential secret is mounted."
  type        = string
  default     = "/var/secrets/google"
}

variable "mlflow_storage_request" {
  description = "Persistent volume size for MLflow data."
  type        = string
  default     = "10Gi"
}

variable "postgres_storage_request" {
  description = "Persistent volume size for the PostgreSQL database."
  type        = string
  default     = "20Gi"
}

variable "storage_class_name" {
  description = "StorageClass used for both MLflow and PostgreSQL PVCs."
  type        = string
  default     = "standard-rwo"
}

variable "postgres_image" {
  description = "Container image for PostgreSQL."
  type        = string
  default     = "postgres:15-alpine"
}

variable "use_existing_postgres_secret" {
  description = "Set to true to read credentials from an existing secret instead of providing them via variables."
  type        = bool
  default     = true
}

variable "postgres_secret_name" {
  description = "Name of the Kubernetes secret holding PostgreSQL credentials."
  type        = string
  default     = "postgres-secret"
}

variable "postgres_user" {
  description = "PostgreSQL username. Required when use_existing_postgres_secret is false."
  type        = string
  default     = null
}

variable "postgres_password" {
  description = "PostgreSQL password. Required when use_existing_postgres_secret is false."
  type        = string
  default     = null
}

variable "postgres_database" {
  description = "PostgreSQL database name. Required when use_existing_postgres_secret is false."
  type        = string
  default     = null
}

variable "use_existing_oauth2_secret" {
  description = "Set to true to reuse credentials from an existing oauth2-proxy secret."
  type        = bool
  default     = true
}

variable "oauth2_secret_name" {
  description = "Name of the oauth2-proxy secret."
  type        = string
  default     = "oauth2-proxy-secret"
}

variable "oauth2_client_id" {
  description = "Google OAuth client ID. Required when use_existing_oauth2_secret is false."
  type        = string
  default     = null
}

variable "oauth2_client_secret" {
  description = "Google OAuth client secret. Required when use_existing_oauth2_secret is false."
  type        = string
  default     = null
}

variable "oauth2_cookie_secret" {
  description = "Secret used to sign oauth2-proxy cookies. Required when use_existing_oauth2_secret is false."
  type        = string
  default     = null
}

variable "oauth2_desktop_client_id" {
  description = "Optional Google desktop client ID for native apps."
  type        = string
  default     = null
}

variable "oauth2_replicas" {
  description = "Number of oauth2-proxy pods."
  type        = number
  default     = 2
}

variable "email_domains" {
  description = "Allowed Google Workspace domains for authentication."
  type        = list(string)
  default     = []
}

variable "allowed_emails" {
  description = "Explicit list of allowed emails (optional)."
  type        = list(string)
  default     = []
}
