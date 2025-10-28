locals {
  zone_filter = var.account_id == null ? {} : { account_id = var.account_id }
}

data "cloudflare_zone" "this" {
  name = var.zone_name

  dynamic "account" {
    for_each = var.account_id == null ? [] : [var.account_id]
    content {
      id = account.value
    }
  }
}
