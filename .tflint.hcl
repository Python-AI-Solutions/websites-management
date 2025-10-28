config {
  module = true
  force  = false
}

plugin "terraform" {
  enabled = true
}

plugin "cloudflare" {
  enabled = true
  version = "0.4.0"
  source  = "terraform-linters/tflint-ruleset-cloudflare"
}
