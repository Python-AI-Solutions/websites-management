terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Create a Google Cloud Storage bucket
resource "google_storage_bucket" "main" {
  name          = var.bucket_name
  location      = var.location
  force_destroy = var.force_destroy

  # Uniform bucket-level access
  uniform_bucket_level_access = var.uniform_bucket_level_access

  # Versioning configuration
  versioning {
    enabled = var.enable_versioning
  }

  # Lifecycle rules (optional example)
  dynamic "lifecycle_rule" {
    for_each = var.enable_lifecycle_rules ? [1] : []
    content {
      condition {
        age = 30
      }
      action {
        type = "Delete"
      }
    }
  }
}

# Create a service account for bucket administration
resource "google_service_account" "bucket_admin" {
  account_id   = var.service_account_name
  display_name = "GCS Bucket Admin Service Account"
  description  = "Service account with admin access to ${var.bucket_name}"
}

# Grant storage admin role to the service account for the bucket
resource "google_storage_bucket_iam_member" "admin" {
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.bucket_admin.email}"
}

# Optionally grant objectAdmin role at the project level
resource "google_project_iam_member" "storage_object_admin" {
  count   = var.grant_project_level_access ? 1 : 0
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.bucket_admin.email}"
}

# Create a service account key for authentication
resource "google_service_account_key" "bucket_admin_key" {
  service_account_id = google_service_account.bucket_admin.name
  key_algorithm      = "KEY_ALG_RSA_2048"
}

# Save the service account key to a local file
resource "local_file" "service_account_key" {
  filename = "${path.module}/${var.service_account_name}-key.json"
  content  = base64decode(google_service_account_key.bucket_admin_key.private_key)

  # Set appropriate permissions on the key file
  file_permission = "0600"
}
