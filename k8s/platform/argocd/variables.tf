variable "namespace" {
  description = "Namespace where Argo CD will be installed."
  type        = string
  default     = "argocd"
}

variable "create_namespace" {
  description = "Whether to create the Argo CD namespace if it does not already exist."
  type        = bool
  default     = true
}

variable "helm_release_name" {
  description = "Name of the Helm release for Argo CD."
  type        = string
  default     = "argo-cd"
}

variable "helm_repository" {
  description = "Helm repository URL for the Argo CD chart."
  type        = string
  default     = "https://argoproj.github.io/argo-helm"
}

variable "helm_chart_version" {
  description = "Version of the Argo CD Helm chart to install."
  type        = string
  default     = "6.7.12"
}

variable "helm_values" {
  description = "Additional Helm values files to apply."
  type        = list(string)
  default     = []
}

variable "helm_set" {
  description = "Map of Helm set values for fine-grained overrides."
  type        = map(string)
  default     = {}
}

variable "app_projects" {
  description = "Argo CD AppProjects to create keyed by project name."
  type = map(object({
    description  = optional(string)
    source_repos = optional(list(string), ["*"])
    destinations = optional(list(object({
      namespace = string
      server    = optional(string, "https://kubernetes.default.svc")
    })), [])
    cluster_resource_whitelist = optional(list(object({
      group = string
      kind  = string
    })), [])
    namespace_resource_whitelist = optional(list(object({
      group = string
      kind  = string
    })), [])
  }))
  default = {}
}

variable "applications" {
  description = "Argo CD Applications keyed by application name."
  type = map(object({
    project = string
    source = object({
      repo_url          = string
      path              = optional(string)
      chart             = optional(string)
      target_revision   = optional(string, "HEAD")
      directory_recurse = optional(bool, false)
      helm = optional(object({
        values      = optional(list(string), [])
        parameters  = optional(map(string), {})
        value_files = optional(list(string), [])
      }))
    })
    destination = object({
      namespace = optional(string)
      server    = optional(string, "https://kubernetes.default.svc")
    })
    sync_policy = optional(object({
      automated = optional(object({
        prune       = optional(bool, true)
        self_heal   = optional(bool, true)
        allow_empty = optional(bool, false)
      }))
      retry = optional(object({
        limit = optional(number)
      }))
    }))
  }))
  default = {}
}
