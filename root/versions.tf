terraform {
  required_version = ">= 1.7.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.30"
    }
  }

  # Uncomment and adjust to migrate to a remote backend (e.g. R2 + DynamoDB for state locking)
  # backend "s3" {
  #   bucket = "TODO-replace-with-bucket"
  #   key    = "cloudflare-dns/terraform.tfstate"
  #   region = "auto"
  #   endpoint = "https://<account>.r2.cloudflarestorage.com"
  #   skip_credentials_validation = true
  #   skip_region_validation      = true
  #   dynamodb_table              = "TODO-replace-with-lock-table"
  #   access_key                  = "TODO"
  #   secret_key                  = "TODO"
  # }
}
