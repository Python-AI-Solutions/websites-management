# oauth2_proxy module

Reusable Terraform module that deploys an [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) instance with Google OAuth credentials, Kubernetes Secret, Deployment, and Service. The module focuses on opinionated defaults for Google authentication while remaining customizable through optional variables.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name` | Logical name/prefix for resources | string | – |
| `namespace` | Target namespace | string | – |
| `create_namespace` | Create namespace if missing | bool | `true` |
| `client_id` | Google OAuth2 web client ID | string | – |
| `client_secret` | Google OAuth2 web client secret | string | – |
| `desktop_client_id` | Optional desktop client ID for JWT support | string | `null` |
| `cookie_secret` | Optional pre-generated (base64) cookie secret | string | `null` |
| `redirect_url` | OAuth2 redirect/callback URL | string | – |
| `upstreams` | List of upstream URLs | list(string) | – |
| `email_domains` | Allowed email domains | list(string) | `[]` |
| `allowed_emails` | Allowed individual emails | list(string) | `[]` |
| `extra_args` | Extra command-line args | list(string) | `[]` |
| `image` | oauth2-proxy image | string | `quay.io/oauth2-proxy/oauth2-proxy:v7.6.0` |
| `replicas` | Deployment replicas | number | `2` |
| `listen_port` | Container listening port | number | `4180` |
| `cookie_refresh` | Cookie refresh interval | string | `1h` |
| `cookie_secure` | Secure cookies | bool | `true` |
| `skip_provider_button` | Hide provider button | bool | `true` |
| `skip_jwt_bearer_tokens` | Accept JWT bearer tokens | bool | `true` |
| `pass_access_token` | Pass access token upstream | bool | `true` |
| `pass_user_headers` | Pass user headers upstream | bool | `true` |
| `set_authorization_header` | Set Authorization header | bool | `true` |
| `set_xauthrequest` | Set X-Auth-Request headers | bool | `true` |
| `service_name` | Override Service name | string | `null` |
| `service_type` | Service type | string | `ClusterIP` |
| `service_port` | Service port | number | `80` |
| `service_annotations` | Service annotations | map(string) | `{}` |
| `deployment_name` | Override Deployment name | string | `null` |
| `pod_annotations` | Pod annotations | map(string) | `{}` |
| `pod_labels` | Extra pod labels | map(string) | `{}` |
| `selector_labels` | Additional selector labels | map(string) | `{}` |
| `extra_env` | Extra environment variables | map(string) | `{}` |
| `extra_secret_data` | Extra Secret key/values | map(string) | `{}` |
| `resources` | Container resources | object | `null` |
| `node_selector` | Node selector | map(string) | `{}` |
| `tolerations` | Pod tolerations | list(object) | `[]` |

## Outputs

- `namespace` – Namespace containing created resources
- `deployment_name` – Deployment name
- `service_name` – Service name
- `secret_name` – Secret name
- `cookie_secret` – Base64 cookie secret (sensitive)
- `args` – Resolved oauth2-proxy arguments
- `redirect_url` – Redirect URL
- `upstreams` – Upstream list

## Example

```hcl
module "example_oauth2" {
  source = "../modules/oauth2_proxy"

  name          = "demo"
  namespace     = "demo"
  client_id     = var.client_id
  client_secret = var.client_secret
  redirect_url  = "https://demo.example.com/oauth2/callback"
  upstreams     = ["http://demo.demo.svc.cluster.local"]
  email_domains = ["example.com"]
}
```

The module intentionally leaves ingress configuration to callers so that Traefik, NGINX, or other ingress controllers can be layered as needed.
