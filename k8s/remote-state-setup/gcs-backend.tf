# GCS Backend Setup (Option A)
# This creates a Google Cloud Storage bucket for Terraform state

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  # Use local backend for this bootstrap
  backend "local" {}
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the bucket"
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "Name for the state bucket (leave empty for auto-generated)"
  type        = string
  default     = ""
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Create GCS bucket for Terraform state
resource "google_storage_bucket" "tfstate" {
  name     = var.bucket_name != "" ? var.bucket_name : "k8s-tfstate-${var.project_id}"
  location = "US"
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }
}

output "bucket_name" {
  description = "Name of the created GCS bucket"
  value       = google_storage_bucket.tfstate.name
}

output "next_steps" {
  description = "Instructions for using this bucket"
  value = <<-EOT
    GCS bucket created: ${google_storage_bucket.tfstate.name}
    
    Next steps:
    1. Update ../main.tf with this backend configuration:
    
    terraform {
      backend "gcs" {
        bucket = "${google_storage_bucket.tfstate.name}"
        prefix = "k8s-cluster/terraform.tfstate"
      }
    }
    
    2. Run: cd .. && tofu init -migrate-state
    3. Confirm state migration when prompted
  EOT
}
