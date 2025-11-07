output "bucket_name" {
  description = "The name of the created GCS bucket"
  value       = google_storage_bucket.main.name
}

output "bucket_url" {
  description = "The URL of the created GCS bucket"
  value       = google_storage_bucket.main.url
}

output "bucket_self_link" {
  description = "The self link of the created GCS bucket"
  value       = google_storage_bucket.main.self_link
}

output "bucket_location" {
  description = "The location of the created GCS bucket"
  value       = google_storage_bucket.main.location
}

output "service_account_email" {
  description = "The email address of the bucket admin service account"
  value       = google_service_account.bucket_admin.email
}

output "service_account_id" {
  description = "The ID of the bucket admin service account"
  value       = google_service_account.bucket_admin.id
}

output "service_account_unique_id" {
  description = "The unique ID of the bucket admin service account"
  value       = google_service_account.bucket_admin.unique_id
}

output "service_account_key_file" {
  description = "The path to the service account key file"
  value       = local_file.service_account_key.filename
}

output "service_account_key_algorithm" {
  description = "The algorithm used for the service account key"
  value       = google_service_account_key.bucket_admin_key.key_algorithm
}

output "setup_instructions" {
  description = "Instructions for using the service account credentials"
  value       = <<-EOT
    To use the service account credentials:

    1. The service account key has been saved to: ${local_file.service_account_key.filename}

    2. Set the environment variable:
       export GOOGLE_APPLICATION_CREDENTIALS="${abspath(local_file.service_account_key.filename)}"

    3. You can now use any GCS client library or gsutil with these credentials:
       gsutil ls gs://${google_storage_bucket.main.name}/

    4. The service account ${google_service_account.bucket_admin.email} has full admin access to the bucket.

    IMPORTANT: Keep the service account key file secure and never commit it to version control!
  EOT
}
