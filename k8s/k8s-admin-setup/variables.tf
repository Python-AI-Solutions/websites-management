variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
  default     = "midyear-pattern-470017-b8"
  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID must not be empty."
  }
}

variable "project_number" {
  description = "The GCP project number (used for Cloud Build service account)"
  type        = string
  default     = "1098946209440"  # For midyear-pattern-470017-b8
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "service_account_name" {
  description = "Name for the Kubernetes administrator service account"
  type        = string
  default     = "k8s-admin"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.service_account_name))
    error_message = "Service account name must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "enable_custom_role" {
  description = "Whether to create a custom role with minimal permissions instead of using predefined roles"
  type        = bool
  default     = false
}

variable "additional_iam_roles" {
  description = "Additional IAM roles to assign to the service account"
  type        = list(string)
  default     = []
}

variable "create_service_account_key" {
  description = "Whether to create a service account key (set to false if using workload identity)"
  type        = bool
  default     = true
}
