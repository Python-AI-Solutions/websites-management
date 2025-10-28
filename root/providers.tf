provider "cloudflare" {
  api_token  = var.cloudflare_api_token != "" ? var.cloudflare_api_token : null
  account_id = var.cloudflare_account_id != "" ? var.cloudflare_account_id : null
}
