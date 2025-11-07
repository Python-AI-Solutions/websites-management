output "service_account_email" {
  description = "Email address of the created service account"
  value       = google_service_account.k8s_admin.email
}

output "service_account_id" {
  description = "The service account ID"
  value       = google_service_account.k8s_admin.id
}

output "service_account_unique_id" {
  description = "The unique ID of the service account"
  value       = google_service_account.k8s_admin.unique_id
}

# Commented out - using existing key
# output "service_account_key_id" {
#   description = "The ID of the service account key"
#   value       = var.create_service_account_key ? google_service_account_key.k8s_admin_key.id : null
#   sensitive   = true
# }

# Commented out - using existing key
# output "service_account_private_key" {
#   description = "The private key of the service account (base64 encoded)"
#   value       = var.create_service_account_key ? google_service_account_key.k8s_admin_key.private_key : null
#   sensitive   = true
# }

# Commented out - using existing key
# output "service_account_key_json" {
#   description = "The service account key in JSON format (base64 encoded)"
#   value       = var.create_service_account_key ? base64decode(google_service_account_key.k8s_admin_key.private_key) : null
#   sensitive   = true
# }

output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "enabled_apis" {
  description = "List of enabled APIs"
  value       = [for api in google_project_service.required_apis : api.service]
}

output "assigned_roles" {
  description = "List of IAM roles assigned to the service account"
  value       = [for role in google_project_iam_member.k8s_admin_roles : role.role]
}

# Instructions for using the service account
output "usage_instructions" {
  description = "Instructions for using the created service account"
  sensitive   = true
  value = <<-EOT
    To use this service account for Kubernetes operations:

    1. Use the existing service account key file:
       # Key file: k8s-admin-key.json (already shared with user)

    2. Set the GOOGLE_APPLICATION_CREDENTIALS environment variable:
       export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/k8s-admin-key.json"

    3. Authenticate with gcloud:
       gcloud auth activate-service-account --key-file=k8s-admin-key.json

    4. Set the project:
       gcloud config set project ${var.project_id}

    5. Get credentials for kubectl:
       gcloud container clusters get-credentials CLUSTER_NAME --region=REGION

    Service Account Email: ${google_service_account.k8s_admin.email}
  EOT
}
