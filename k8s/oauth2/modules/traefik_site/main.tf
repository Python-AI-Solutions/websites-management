locals {
  ingress_route_name = coalesce(var.ingress_route_name, "${var.name}-ingress")
  forward_auth_name  = coalesce(var.forward_auth_middleware_name, "${var.name}-forward-auth")
  forward_auth_ns    = coalesce(var.forward_auth_middleware_namespace, var.namespace)
  entrypoints        = length(var.entrypoints) > 0 ? var.entrypoints : ["websecure"]

  forward_auth_address = var.proxy_service_name == null ? null : (
    var.proxy_service_port == 80
    ? "http://${var.proxy_service_name}.${var.namespace}.svc.cluster.local${var.forward_auth_path}"
    : "http://${var.proxy_service_name}.${var.namespace}.svc.cluster.local:${var.proxy_service_port}${var.forward_auth_path}"
  )

  header_middlewares_map = {
    for hm in var.header_middlewares :
    "${coalesce(hm.namespace, var.namespace)}/${hm.name}" => hm
  }

  header_middlewares_root = [
    for _, hm in local.header_middlewares_map : merge(
      { name = hm.name },
      hm.namespace != null ? { namespace = hm.namespace } : { namespace = var.namespace }
    )
    if hm.attach_to_root != false
  ]

  extra_middlewares = [
    for m in var.extra_root_middlewares : merge(
      { name = m.name },
      m.namespace != null ? { namespace = m.namespace } : {}
    )
  ]

  forward_auth_middleware_ref = (
    var.proxy_service_name != null &&
    var.root_route_backend == "upstream" &&
    (var.forward_auth_middleware_name != null || var.create_forward_auth_middleware)
    ) ? [
    merge(
      { name = local.forward_auth_name },
      var.forward_auth_middleware_namespace != null ? { namespace = var.forward_auth_middleware_namespace } : { namespace = var.namespace }
    )
  ] : []

  root_route_middlewares = concat(
    var.root_route_backend == "upstream" ? local.forward_auth_middleware_ref : [],
    local.header_middlewares_root,
    local.extra_middlewares
  )

  proxy_service_block = var.proxy_service_name == null ? null : {
    name = var.proxy_service_name
    port = var.proxy_service_port
  }

  upstream_service_block = var.upstream_service_name == null ? null : {
    name = var.upstream_service_name
    port = var.upstream_service_port
  }

  root_route_service = var.root_route_backend == "proxy" ? local.proxy_service_block : local.upstream_service_block

  root_route_services = local.root_route_service == null ? [] : [local.root_route_service]

  oauth2_routes = local.proxy_service_block == null ? [] : [
    {
      kind     = "Rule"
      match    = "Host(`${var.host}`) && PathPrefix(`/oauth2`)"
      services = [local.proxy_service_block]
    }
  ]

  root_route = merge(
    {
      kind     = "Rule"
      match    = "Host(`${var.host}`) && PathPrefix(`/`)"
      services = local.root_route_services
    },
    length(local.root_route_middlewares) > 0 ? { middlewares = local.root_route_middlewares } : {}
  )

  routes = concat(local.oauth2_routes, [local.root_route])

  tls_block = {
    for k, v in {
      secretName   = var.tls_secret_name
      certResolver = var.tls_cert_resolver
      domains      = var.tls_cert_resolver != null ? [{ main = var.host }] : null
    } : k => v if v != null
  }

  ingress_spec = merge(
    {
      entryPoints = local.entrypoints
      routes      = local.routes
    },
    length(local.tls_block) > 0 ? { tls = local.tls_block } : {}
  )
}

resource "kubernetes_manifest" "forward_auth" {
  count = (
    var.proxy_service_name != null &&
    var.root_route_backend == "upstream" &&
    var.create_forward_auth_middleware
  ) ? 1 : 0

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = local.forward_auth_name
      namespace = local.forward_auth_ns
    }
    spec = {
      forwardAuth = {
        address             = local.forward_auth_address
        trustForwardHeader  = var.forward_auth_trust_forward_header
        authResponseHeaders = var.forward_auth_additional_headers
      }
    }
  }
}

resource "kubernetes_manifest" "header_middleware" {
  for_each = local.header_middlewares_map

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = each.value.name
      namespace = coalesce(each.value.namespace, var.namespace)
    }
    spec = {
      headers = merge(
        {
          accessControlAllowCredentials = false
          addVaryHeader                 = false
          browserXssFilter              = false
          contentTypeNosniff            = false
          forceSTSHeader                = false
          frameDeny                     = false
          isDevelopment                 = false
          sslForceHost                  = false
          sslRedirect                   = false
          sslTemporaryRedirect          = false
          stsIncludeSubdomains          = false
          stsPreload                    = false
        },
        length(try(each.value.request_headers, {})) > 0 ? {
          customRequestHeaders = each.value.request_headers
        } : {},
        length(try(each.value.response_headers, {})) > 0 ? {
          customResponseHeaders = each.value.response_headers
        } : {}
      )
    }
  }
}

resource "kubernetes_manifest" "ingress_route" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = local.ingress_route_name
      namespace = var.namespace
    }
    spec = local.ingress_spec
  }

  depends_on = [
    kubernetes_manifest.forward_auth,
    kubernetes_manifest.header_middleware
  ]
}
