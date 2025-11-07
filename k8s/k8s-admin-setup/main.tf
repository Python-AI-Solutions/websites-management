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

# Service Account for Kubernetes deployment and administration
resource "google_service_account" "k8s_admin" {
  account_id   = var.service_account_name
  display_name = "Kubernetes Administrator"
  description  = "Service account for deploying and administering Kubernetes clusters"
}

# IAM roles for Kubernetes management (comprehensive permissions for Terraform + GKE)
resource "google_project_iam_member" "k8s_admin_roles" {
  for_each = toset([
    # Core Terraform/API management
    "roles/serviceusage.serviceUsageAdmin",    # Enable/disable APIs (absolutely required)
    "roles/serviceusage.serviceUsageViewer",   # List enabled services
    "roles/serviceusage.serviceUsageConsumer", # Consume quota and billing for services (needed for VM creation)
    "roles/viewer",                            # Basic read access (enables resourcemanager.projects.get)

    # GKE cluster management
    "roles/container.admin",                   # Manage GKE clusters and node pools

    # Compute/Network permissions
    "roles/compute.viewer",                    # View networks/zones (minimum)
    "roles/compute.networkAdmin",              # Create/manage networks, subnets, firewall rules

    # Service account management
    "roles/iam.serviceAccountAdmin",           # Create/manage service accounts
    "roles/iam.serviceAccountUser",            # Let GKE nodes use assigned service accounts

    # Logging and monitoring
    "roles/logging.admin",                     # Setup logging configurations
    "roles/monitoring.admin",                  # Setup monitoring configurations

    # Artifact Registry (for container images)
    "roles/artifactregistry.admin",            # Create/manage Artifact Registry repos

    # Instance permissions
    "roles/compute.instanceAdmin.v1",          # Ability to create Instances/VMs

    # Storage permissions (for Cloud Build and general storage needs)
    "roles/storage.objectAdmin"                # Manage storage objects (needed for Cloud Build staging bucket)
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.k8s_admin.email}"
}

# Optional additional permissions (uncomment if needed)
# resource "google_project_iam_member" "k8s_additional_permissions" {
#   for_each = toset([
#     "roles/compute.networkAdmin",      # Manage VPC networks for clusters
#     "roles/storage.objectAdmin",       # Manage storage buckets for backups/configs
#     "roles/secretmanager.admin"        # Manage secrets (if using Secret Manager)
#   ])
#
#   project = var.project_id
#   role    = each.value
#   member  = "serviceAccount:${google_service_account.k8s_admin.email}"
# }

# Service Account Key for authentication
# COMMENTED OUT: Using existing key shared with Pradyot instead of creating new ones
# resource "google_service_account_key" "k8s_admin_key" {
#   service_account_id = google_service_account.k8s_admin.name
#   public_key_type    = "TYPE_X509_PEM_FILE"
# }

# Optional: Create a custom role with specific permissions if needed
resource "google_project_iam_custom_role" "k8s_deployer" {
  role_id     = "k8sDeployer"
  title       = "Kubernetes Deployer"
  description = "Custom role for Kubernetes deployment with minimal required permissions"

  permissions = [
    "container.clusters.create",
    "container.clusters.delete",
    "container.clusters.get",
    "container.clusters.list",
    "container.clusters.update",
    "container.operations.get",
    "container.operations.list",
    "compute.instances.create",
    "compute.instances.delete",
    "compute.instances.get",
    "compute.instances.list",
    "compute.networks.use",
    "compute.subnetworks.use",
    "storage.buckets.create",
    "storage.buckets.delete",
    "storage.buckets.get",
    "storage.buckets.list",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list"
  ]
}

# Enable required APIs (comprehensive set for GKE + IaC tools)
resource "google_project_service" "required_apis" {
  for_each = toset([
    "container.googleapis.com",            # Google Kubernetes Engine API (required)
    "compute.googleapis.com",              # Compute Engine API (required)
    "serviceusage.googleapis.com",         # Service Usage API (required for IaC tools)
    "cloudresourcemanager.googleapis.com", # Cloud Resource Manager API (required for IaC tools)
    "iam.googleapis.com",                  # Identity and Access Management API (for service account management)
    "logging.googleapis.com",              # Cloud Logging API (for logging configuration)
    "monitoring.googleapis.com",           # Cloud Monitoring API (for monitoring configuration)
    "artifactregistry.googleapis.com",    # Artifact Registry API (for container image management)
    "cloudbuild.googleapis.com"           # Cloud Build API (for building containers)
  ])

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Grant storage permissions to Cloud Build service account
# This allows Cloud Build to access the staging bucket for builds
resource "google_project_iam_member" "cloudbuild_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_project_service.required_apis["cloudbuild.googleapis.com"]
  ]
}
