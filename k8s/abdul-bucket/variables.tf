variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "The name of the GCS bucket to create"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-_.]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be between 3 and 63 characters, and can only contain lowercase letters, numbers, hyphens, underscores, and dots."
  }
}

variable "location" {
  description = "The location for the GCS bucket (e.g., US, EU, us-central1)"
  type        = string
  default     = "US"
}

variable "service_account_name" {
  description = "The name for the service account"
  type        = string
  default     = "gcs-bucket-admin"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.service_account_name))
    error_message = "Service account name must be between 6 and 30 characters, start with a letter, and can only contain lowercase letters, numbers, and hyphens."
  }
}

variable "force_destroy" {
  description = "When deleting the bucket, delete all contained objects"
  type        = bool
  default     = false
}

variable "uniform_bucket_level_access" {
  description = "Enable uniform bucket-level access"
  type        = bool
  default     = true
}

variable "enable_versioning" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = false
}

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules for automatic object deletion"
  type        = bool
  default     = false
}

# variable "kms_key_name" {
#   description = "The Cloud KMS key name for bucket encryption (currently not used - using Google-managed encryption)"
#   type        = string
#   default     = null
# }

variable "grant_project_level_access" {
  description = "Grant the service account project-level storage.objectAdmin access"
  type        = bool
  default     = false
}
