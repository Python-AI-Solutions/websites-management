terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "kubernetes_namespace" "argocd" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}

locals {
  default_helm_values = yamlencode({
    configs = {
      params = {
        "server.enable.grpc-web" = "true"
      }
    }
    server = {
      ingress = {
        enabled = false
      }
    }
  })

  merged_helm_values = concat([local.default_helm_values], var.helm_values)

  helm_set_list = [
    for k, v in var.helm_set : {
      name  = k
      value = v
    }
  ]

  app_project_manifests = {
    for name, cfg in var.app_projects : name => {
      metadata = {
        name      = name
        namespace = var.namespace
      }

      spec = merge(
        {
          sourceRepos = cfg.source_repos
        },
        length(cfg.destinations) > 0 ? {
          destinations = [
            for dest in cfg.destinations : {
              namespace = dest.namespace
              server    = try(dest.server, "https://kubernetes.default.svc")
            }
          ]
        } : {},
        try(cfg.description, null) != null ? {
          description = cfg.description
        } : {},
        length(cfg.cluster_resource_whitelist) > 0 ? {
          clusterResourceWhitelist = cfg.cluster_resource_whitelist
        } : {},
        length(cfg.namespace_resource_whitelist) > 0 ? {
          namespaceResourceWhitelist = cfg.namespace_resource_whitelist
        } : {}
      )
    }
  }

  application_helm_blocks = {
    for name, cfg in var.applications : name => (try(cfg.source.helm, null) == null ? null : merge(
      length(try(cfg.source.helm.value_files, [])) > 0 ? {
        valueFiles = cfg.source.helm.value_files
      } : {},
      length(try(cfg.source.helm.parameters, {})) > 0 ? {
        parameters = [
          for pk, pv in cfg.source.helm.parameters : {
            name  = pk
            value = pv
          }
        ]
      } : {},
      length(try(cfg.source.helm.values, [])) > 0 ? {
        values = join("\n---\n", cfg.source.helm.values)
      } : {}
    ))
  }

  application_sources = {
    for name, cfg in var.applications : name => merge(
      {
        repoURL        = cfg.source.repo_url
        targetRevision = try(cfg.source.target_revision, "HEAD")
      },
      try(cfg.source.path, null) != null ? {
        path = cfg.source.path
      } : {},
      try(cfg.source.chart, null) != null ? {
        chart = cfg.source.chart
      } : {},
      try(cfg.source.directory_recurse, false) ? {
        directory = {
          recurse = true
        }
      } : {},
      local.application_helm_blocks[name] != null ? {
        helm = local.application_helm_blocks[name]
      } : {}
    )
  }

  application_destinations = {
    for name, cfg in var.applications : name => merge(
      {
        server = try(cfg.destination.server, "https://kubernetes.default.svc")
      },
      try(cfg.destination.namespace, null) != null ? {
        namespace = cfg.destination.namespace
      } : {}
    )
  }

  application_sync_policies = {
    for name, cfg in var.applications : name => (
      try(cfg.sync_policy, null) == null ? null : merge(
        try(cfg.sync_policy.automated, null) != null ? {
          automated = merge(
            try(cfg.sync_policy.automated.prune, null) != null ? { prune = cfg.sync_policy.automated.prune } : {},
            try(cfg.sync_policy.automated.self_heal, null) != null ? { selfHeal = cfg.sync_policy.automated.self_heal } : {},
            try(cfg.sync_policy.automated.allow_empty, null) != null ? { allowEmpty = cfg.sync_policy.automated.allow_empty } : {}
          )
        } : {},
        try(cfg.sync_policy.retry, null) != null ? {
          retry = merge(
            try(cfg.sync_policy.retry.limit, null) != null ? { limit = cfg.sync_policy.retry.limit } : {}
          )
        } : {}
      )
    )
  }

  application_manifests = {
    for name, cfg in var.applications : name => {
      metadata = {
        name      = name
        namespace = var.namespace
      }
      project     = cfg.project
      source      = local.application_sources[name]
      destination = local.application_destinations[name]
      sync_policy = local.application_sync_policies[name]
    }
  }
}

resource "helm_release" "argocd" {
  name       = var.helm_release_name
  repository = var.helm_repository
  chart      = "argo-cd"
  version    = var.helm_chart_version

  namespace = var.namespace

  values = local.merged_helm_values

  dynamic "set" {
    for_each = local.helm_set_list
    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  depends_on = [kubernetes_namespace.argocd]
}

resource "kubernetes_manifest" "app_project" {
  for_each = local.app_project_manifests

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata   = each.value.metadata
    spec       = each.value.spec
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "application" {
  for_each = local.application_manifests

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata   = each.value.metadata
    spec = merge(
      {
        project     = each.value.project
        source      = each.value.source
        destination = each.value.destination
      },
      each.value.sync_policy != null ? { syncPolicy = each.value.sync_policy } : {}
    )
  }

  depends_on = [helm_release.argocd]
}
