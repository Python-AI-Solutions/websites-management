# Reusable Google OAuth2 Proxy Stack

The `oauth2` directory wraps the reusable modules that deploy [`oauth2-proxy`](https://oauth2-proxy.github.io/oauth2-proxy/) into our clusters. It supports two usage patterns:

1. **Single-site module** – `modules/oauth2_proxy` creates the Deployment/Service/Secret for one oauth2-proxy instance.
2. **Composite stack** – the root module (`main.tf`) lets you define a map of proxies (`var.sites`) and optional Traefik wiring (`var.traefik_sites`) in a single apply.

Use these modules whenever a service needs Google OAuth in front of it; they handle cookie secret generation, desktop extra JWT issuers, and consistent command-line args.

---

## Module Overview

### `modules/oauth2_proxy`

| Variable | Purpose |
|----------|---------|
| `namespace` / `create_namespace` | Target namespace and whether to create it |
| `client_id` / `client_secret` | OAuth Web client credentials (base64 handled for you) |
| `cookie_secret` | 32-byte signing secret (pass in plain text; module encodes it) |
| `desktop_client_id` | Optional desktop client for extra JWT issuers |
| `redirect_url` | Callback URL (e.g. `https://mlflow.example.com/oauth2/callback`) |
| `upstreams` | List of upstream URLs (e.g. internal service ClusterIPs) |
| `email_domains` / `allowed_emails` | Access control lists |
| `extra_args`, `extra_env` | Escape hatch for additional oauth2-proxy flags/env |

Outputs expose the deployment/service names, generated cookie secret (if Terraform created it), and the computed oauth2-proxy CLI arguments.

### `modules/traefik_site`

Defines the Traefik resources (IngressRoute + middlewares) that point at an oauth2-proxy or upstream app. Used directly by `platform/traefik-sites` and available here if you need customised routing.

---

## Using the Root Module (`oauth2/`)

Example `terraform.tfvars`:

```hcl
sites = {
  mlflow = {
    namespace         = "mlflow"
    client_id         = var.mlflow_client_id
    client_secret     = var.mlflow_client_secret
    cookie_secret     = var.mlflow_cookie_secret
    desktop_client_id = var.mlflow_desktop_client_id
    redirect_url      = "https://mlflow.example.com/oauth2/callback"
    upstreams         = ["http://mlflow.mlflow.svc.cluster.local"]
    email_domains     = ["example.com"]
  }
}

traefik_sites = {
  mlflow = {
    namespace          = "mlflow"
    host               = "mlflow.example.com"
    proxy_service_name = "oauth2-proxy"
    tls_cert_resolver  = "letsencrypt"
  }
}
```

Then:

```bash
cd oauth2
tofu init
tofu plan
tofu apply
```

The stack will create the oauth2-proxy Deployment/Service/Secret and, if supplied, the Traefik ingress objects.

---

## Standalone Module Usage

When a platform stack only needs the oauth2-proxy Deployment (and manages ingress separately), call the module directly, as done in `platform/mlflow/main.tf`:

```hcl
module "oauth2_proxy" {
  source = "../../oauth2/modules/oauth2_proxy"

  name             = "mlflow"
  namespace        = var.namespace
  client_id        = local.oauth2_client_id_plain
  client_secret    = local.oauth2_client_secret_plain
  cookie_secret    = local.oauth2_cookie_secret_plain
  desktop_client_id = local.oauth2_desktop_client_id_plain
  redirect_url     = "https://${var.mlflow_host}/oauth2/callback"
  upstreams        = ["http://mlflow.${var.namespace}.svc.cluster.local"]
  email_domains    = var.email_domains
}
```

The module takes care of base64 encoding secrets and composing the oauth2-proxy CLI arguments.

---

## Secrets & Security

* `client_id` / `client_secret` / `desktop_client_id` should be provided through `terraform.tfvars` or your secrets manager. Avoid committing real values.
* `cookie_secret` must be 16, 24, or 32 bytes. The module will generate one automatically if you pass `null`, but in production we recommend supplying a fixed value (store it in your secrets manager) so pods can roll without invalidating sessions.
* The desktop client is optional; when provided, the module adds `--extra-jwt-issuers=https://accounts.google.com=<desktop-client-id>` so native apps can present ID tokens to oauth2-proxy.

---

## Validation Checklist

```bash
# Verify deployment
kubectl get pods -n <namespace> -l app=<name>-oauth2-proxy

# Check the service
kubectl get svc -n <namespace> <name>-oauth2-proxy

# Inspect the secret
kubectl get secret -n <namespace> <name>-oauth2-proxy-secret -o yaml

# (If using traefik_site) confirm route exists
kubectl get ingressroute -n <namespace> <name>-ingress
```

Combine this with HTTP checks (e.g. call `https://<host>/oauth2/start`) to confirm Google OAuth is wired correctly.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `invalid_cookie_secret` logs | Secret length not 16/24/32 bytes | Regenerate and update `cookie_secret` |
| Google login loops | Redirect URL mismatch | Ensure OAuth consent screen + client has the correct callback | 
| 403 after login | Email domain whitelist blocking user | Update `email_domains` / `allowed_emails` and reapply |
| Traefik 404 | Ingress host misconfigured | Verify `host` parameter and DNS |

---

## Maintenance

* Rotate OAuth credentials by updating `terraform.tfvars` and reapplying; the module will update the Kubernetes secret and roll the deployment.
* Upgrade oauth2-proxy by overriding the `image` variable (`modules/oauth2_proxy` accepts `image` and `replicas`).
* Use the module outputs (`proxies`, `traefik_sites`) to surface computed arguments or resource names into higher-level stacks or CI pipelines.

This directory is intentionally generic—share the module across services whenever they need Google-backed authentication.
