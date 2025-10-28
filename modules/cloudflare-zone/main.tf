resource "cloudflare_zone" "this" {
  account_id = var.account_id
  zone       = var.zone_name
  plan       = "free"

  lifecycle {
    # Prevent destruction of the zone if account_id changes
    # This is a computed field that may not be set on import
    ignore_changes = [account_id]
  }
}
