variable "name" {
  description = "Logical name for this Traefik ingress configuration."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the Traefik resources (IngressRoute/Middleware) will be created."
  type        = string
}

variable "host" {
  description = "Hostname served by the IngressRoute."
  type        = string
}

variable "proxy_service_name" {
  description = "Optional service name for oauth2-proxy. When null, no /oauth2 route or forward-auth middleware is created."
  type        = string
  default     = null
}

variable "proxy_service_port" {
  description = "Service port for the oauth2-proxy Service."
  type        = number
  default     = 80
}

variable "root_route_backend" {
  description = "Destination for the catch-all route. Use 'proxy' to send traffic to oauth2-proxy, or 'upstream' to send traffic directly to the protected app with forward-auth."
  type        = string
  default     = "proxy"
  validation {
    condition     = contains(["proxy", "upstream"], var.root_route_backend)
    error_message = "root_route_backend must be either 'proxy' or 'upstream'."
  }
}

variable "upstream_service_name" {
  description = "Kubernetes Service name for the protected upstream app (required when root_route_backend = 'upstream')."
  type        = string
  default     = null
}

variable "upstream_service_port" {
  description = "Service port for the protected upstream app (required when root_route_backend = 'upstream')."
  type        = number
  default     = null
}

variable "entrypoints" {
  description = "Traefik entrypoints to attach to the IngressRoute."
  type        = list(string)
  default     = ["web", "websecure"]
}

variable "tls_secret_name" {
  description = "Name of the TLS secret to attach to the IngressRoute (optional)."
  type        = string
  default     = null
}

variable "tls_cert_resolver" {
  description = "Name of the Traefik certResolver to use for TLS (optional)."
  type        = string
  default     = null
}

variable "ingress_route_name" {
  description = "Override for the IngressRoute resource name. Defaults to <name>-ingress."
  type        = string
  default     = null
}

variable "create_forward_auth_middleware" {
  description = "Whether to create a Traefik Middleware for forward-auth pointing at oauth2-proxy."
  type        = bool
  default     = true
}

variable "forward_auth_middleware_name" {
  description = "Name of the forward-auth middleware. Defaults to <name>-forward-auth."
  type        = string
  default     = null
}

variable "forward_auth_middleware_namespace" {
  description = "Namespace where the forward-auth middleware resides. Defaults to the provided namespace."
  type        = string
  default     = null
}

variable "forward_auth_path" {
  description = "Path on the oauth2-proxy service used for forward-auth."
  type        = string
  default     = "/oauth2/auth"
}

variable "forward_auth_trust_forward_header" {
  description = "Whether the middleware should trust X-Forwarded headers from Traefik."
  type        = bool
  default     = true
}

variable "forward_auth_additional_headers" {
  description = "List of headers to pass from oauth2-proxy back to the upstream service during forward-auth."
  type        = list(string)
  default = [
    "X-Auth-Request-Email",
    "X-Auth-Request-User",
    "Authorization"
  ]
}

variable "header_middlewares" {
  description = "List of header middlewares to create. Each middleware can optionally attach to the root route."
  type = list(object({
    name             = string
    namespace        = optional(string)
    attach_to_root   = optional(bool, true)
    request_headers  = optional(map(string), {})
    response_headers = optional(map(string), {})
  }))
  default = []
}

variable "extra_root_middlewares" {
  description = "Additional middlewares to attach to the catch-all route."
  type = list(object({
    name      = string
    namespace = optional(string)
  }))
  default = []
}
