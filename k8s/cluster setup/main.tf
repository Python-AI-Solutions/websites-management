terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "Default region for resources"
  type        = string
  default     = "us-central1" # or whatever you need
}

provider "google" {
  credentials = file("/Users/pradyotranjan/gcp-k8s-admin-setup/k8s-admin-key.json")
  project     = "midyear-pattern-470017-b8"
  region      = "us-central1"
}

# 0) Enable Service Usage itself FIRST, so TF can list/enable other APIs
resource "google_project_service" "serviceusage" {
  project            = var.project_id
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
}

# 1) Enable required Google APIs (waits for serviceusage)
resource "google_project_service" "required_apis" {
  for_each = toset([
    "container.googleapis.com",        # GKE
    "compute.googleapis.com",          # VM/network
    "iam.googleapis.com",              # service accounts
    "logging.googleapis.com",          # Cloud Logging
    "monitoring.googleapis.com",       # Cloud Monitoring
    "artifactregistry.googleapis.com", # images
    # (optional but often useful)
    "cloudresourcemanager.googleapis.com"
  ])
  project                       = var.project_id
  service                       = each.key
  disable_on_destroy            = false
  disable_dependent_services    = false
  depends_on                    = [google_project_service.serviceusage]
}

resource "google_container_cluster" "primary" {
  name                     = var.cluster_name
  location                 = var.cluster_location
  project                  = var.project_id
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-nodes"
  location   = var.cluster_location
  project    = var.project_id
  cluster    = google_container_cluster.primary.name

  node_count = var.enable_autoscaling ? null : var.node_count

  node_config {
    service_account = var.service_account_email
    machine_type    = var.node_machine_type
    disk_size_gb    = var.node_disk_size_gb
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  dynamic "autoscaling" {
    for_each = var.enable_autoscaling ? [1] : []
    content {
      min_node_count = var.autoscaling_min_nodes
      max_node_count = var.autoscaling_max_nodes
    }
  }

  depends_on = [google_project_service.required_apis]
}
