variable "name" {
  description = "Logical name for this oauth2-proxy instance; used as a prefix for resource names unless explicit overrides are provided."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the oauth2-proxy resources will live."
  type        = string
}

variable "create_namespace" {
  description = "Whether to create the namespace if it does not already exist."
  type        = bool
  default     = true
}

variable "client_id" {
  description = "Google OAuth2 web client ID."
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Google OAuth2 web client secret."
  type        = string
  sensitive   = true
}

variable "desktop_client_id" {
  description = "Optional desktop client ID for JWT bearer token support."
  type        = string
  default     = null
  sensitive   = true
}

variable "cookie_secret" {
  description = "Optional pre-generated cookie secret (base64 encoded) to use instead of generating one."
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_name" {
  description = "Name of the Kubernetes Secret that will hold OAuth2 credentials."
  type        = string
  default     = null
}

variable "redirect_url" {
  description = "OAuth2 redirect URL used by oauth2-proxy."
  type        = string
}

variable "upstreams" {
  description = "List of upstream URLs that oauth2-proxy should forward authenticated traffic to."
  type        = list(string)
}

variable "email_domains" {
  description = "List of allowed email domains; an empty list means no domain restriction."
  type        = list(string)
  default     = []
}

variable "allowed_emails" {
  description = "List of specific email addresses to allow; optional."
  type        = list(string)
  default     = []
}

variable "extra_args" {
  description = "Additional command-line arguments for oauth2-proxy."
  type        = list(string)
  default     = []
}

variable "image" {
  description = "Container image for oauth2-proxy."
  type        = string
  default     = "quay.io/oauth2-proxy/oauth2-proxy:v7.6.0"
}

variable "replicas" {
  description = "Number of oauth2-proxy replicas."
  type        = number
  default     = 2
}

variable "listen_port" {
  description = "Container port oauth2-proxy listens on."
  type        = number
  default     = 4180
}

variable "cookie_refresh" {
  description = "Duration for cookie refresh interval (e.g. 1h)."
  type        = string
  default     = "1h"
}

variable "cookie_secure" {
  description = "Whether oauth2-proxy cookies are marked secure."
  type        = bool
  default     = true
}

variable "skip_provider_button" {
  description = "Whether to skip showing the provider selection button."
  type        = bool
  default     = true
}

variable "skip_jwt_bearer_tokens" {
  description = "Whether to skip re-authentication when a valid JWT bearer token is provided."
  type        = bool
  default     = true
}

variable "pass_access_token" {
  description = "Whether to pass the access token upstream."
  type        = bool
  default     = true
}

variable "pass_user_headers" {
  description = "Whether to pass X-Auth-Request headers upstream."
  type        = bool
  default     = true
}

variable "set_authorization_header" {
  description = "Whether to set the Authorization header for upstream requests."
  type        = bool
  default     = true
}

variable "set_xauthrequest" {
  description = "Whether to set X-Auth-Request headers."
  type        = bool
  default     = true
}

variable "service_name" {
  description = "Name of the Kubernetes Service. Defaults to <name>-oauth2-proxy."
  type        = string
  default     = null
}

variable "service_type" {
  description = "Kubernetes Service type."
  type        = string
  default     = "ClusterIP"
}

variable "service_port" {
  description = "Port exposed by the Service."
  type        = number
  default     = 80
}

variable "service_annotations" {
  description = "Annotations to add to the Service."
  type        = map(string)
  default     = {}
}

variable "deployment_name" {
  description = "Name of the Deployment. Defaults to <name>-oauth2-proxy."
  type        = string
  default     = null
}

variable "pod_annotations" {
  description = "Annotations to apply to the pod template."
  type        = map(string)
  default     = {}
}

variable "pod_labels" {
  description = "Additional labels to apply to the pod template."
  type        = map(string)
  default     = {}
}

variable "selector_labels" {
  description = "Additional selector labels; merged with the default app label."
  type        = map(string)
  default     = {}
}

variable "extra_env" {
  description = "Additional environment variables for the oauth2-proxy container."
  type        = map(string)
  default     = {}
}

variable "extra_secret_data" {
  description = "Additional key/value pairs to include in the secret."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "resources" {
  description = "Optional container resource requests and limits."
  type = object({
    limits   = optional(map(string))
    requests = optional(map(string))
  })
  default = null
}

variable "node_selector" {
  description = "Optional node selector for the Deployment."
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Optional list of tolerations for the pod."
  type = list(object({
    key               = string
    operator          = string
    value             = optional(string)
    effect            = optional(string)
    toleration_seconds = optional(number)
  }))
  default = []
}
