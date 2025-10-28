locals {
  normalized = {
    for label, cfg in var.records :
    label => merge(cfg, {
      label           = label
      sanitized_label = label == "@" ? "apex" : replace(replace(label, ".", "_"), "-", "_")
      record_name     = label == "@" ? var.zone_name : label
      fqdn            = label == "@" ? var.zone_name : "${label}.${var.zone_name}"
    })
  }

  a_records = flatten([
    for label, cfg in local.normalized : [
      for idx, record in cfg.a : {
        key     = "${cfg.sanitized_label}-a-${idx}"
        name    = cfg.record_name
        value   = record.value
        ttl     = try(record.ttl, var.default_ttl)
        proxied = try(record.proxied, var.default_proxied)
      }
    ]
  ])

  aaaa_records = flatten([
    for label, cfg in local.normalized : [
      for idx, record in cfg.aaaa : {
        key     = "${cfg.sanitized_label}-aaaa-${idx}"
        name    = cfg.record_name
        value   = record.value
        ttl     = try(record.ttl, var.default_ttl)
        proxied = try(record.proxied, var.default_proxied)
      }
    ]
  ])

  cname_records = flatten([
    for label, cfg in local.normalized : [
      for idx, record in cfg.cname : {
        key     = "${cfg.sanitized_label}-cname-${idx}"
        name    = cfg.record_name
        value   = record.value
        ttl     = try(record.ttl, var.default_ttl)
        proxied = try(record.proxied, var.default_proxied)
      }
    ]
  ])

  txt_records = flatten([
    for label, cfg in local.normalized : [
      for idx, record in cfg.txt : {
        key   = "${cfg.sanitized_label}-txt-${idx}"
        name  = cfg.record_name
        value = record.value
        ttl   = try(record.ttl, var.default_ttl)
      }
    ]
  ])

  mx_records = flatten([
    for label, cfg in local.normalized : [
      for idx, record in cfg.mx : {
        key      = "${cfg.sanitized_label}-mx-${idx}"
        name     = cfg.record_name
        value    = record.value
        priority = record.priority
        ttl      = try(record.ttl, var.default_ttl)
      }
    ]
  ])

  caa_records = flatten([
    for label, cfg in local.normalized : [
      for idx, record in cfg.caa : {
        key   = "${cfg.sanitized_label}-caa-${idx}"
        name  = cfg.record_name
        tag   = record.tag
        value = record.value
        flags = record.flags
        ttl   = try(record.ttl, var.default_ttl)
      }
    ]
  ])

  ns_records = flatten([
    for label, cfg in local.normalized : [
      for idx, record in cfg.ns : {
        key   = "${cfg.sanitized_label}-ns-${idx}"
        name  = cfg.record_name
        value = record.value
        ttl   = try(record.ttl, var.default_ttl)
      }
    ]
  ])

  srv_records = flatten([
    for label, cfg in local.normalized : [
      for idx, record in cfg.srv : {
        key      = "${cfg.sanitized_label}-srv-${idx}"
        name     = cfg.record_name
        service  = record.service
        proto    = record.proto
        srv_name = record.name
        priority = record.priority
        weight   = record.weight
        port     = record.port
        target   = record.target
        ttl      = try(record.ttl, var.default_ttl)
      }
    ]
  ])
}

resource "cloudflare_record" "a" {
  for_each = { for record in local.a_records : record.key => record }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "A"
  value   = each.value.value
  ttl     = each.value.ttl
  proxied = each.value.proxied
}

resource "cloudflare_record" "aaaa" {
  for_each = { for record in local.aaaa_records : record.key => record }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "AAAA"
  value   = each.value.value
  ttl     = each.value.ttl
  proxied = each.value.proxied
}

resource "cloudflare_record" "cname" {
  for_each = { for record in local.cname_records : record.key => record }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "CNAME"
  value   = each.value.value
  ttl     = each.value.ttl
  proxied = each.value.proxied
}

resource "cloudflare_record" "txt" {
  for_each = { for record in local.txt_records : record.key => record }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "TXT"
  value   = each.value.value
  ttl     = each.value.ttl
}

resource "cloudflare_record" "mx" {
  for_each = { for record in local.mx_records : record.key => record }

  zone_id  = var.zone_id
  name     = each.value.name
  type     = "MX"
  value    = each.value.value
  priority = each.value.priority
  ttl      = each.value.ttl
}

resource "cloudflare_record" "caa" {
  for_each = { for record in local.caa_records : record.key => record }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "CAA"
  ttl     = each.value.ttl

  data {
    tag   = each.value.tag
    flags = each.value.flags
    value = each.value.value
  }
}

resource "cloudflare_record" "ns" {
  for_each = { for record in local.ns_records : record.key => record }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "NS"
  value   = each.value.value
  ttl     = each.value.ttl
}

resource "cloudflare_record" "srv" {
  for_each = { for record in local.srv_records : record.key => record }

  zone_id = var.zone_id
  name    = each.value.name
  type    = "SRV"
  ttl     = each.value.ttl

  data {
    service  = each.value.service
    proto    = each.value.proto
    name     = each.value.srv_name
    priority = each.value.priority
    weight   = each.value.weight
    port     = each.value.port
    target   = each.value.target
  }
}
