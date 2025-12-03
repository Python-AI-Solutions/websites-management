# Traefik Site Definitions

This stack manages Traefik resources that sit outside any single application repository. It creates shared namespaces, reusable header middlewares, and `IngressRoute` definitions for every externally exposed domain (production, staging, MLflow, etc.). Application repos only need to provide Deployments/Services—the routing layer is codified here.

---

## Architecture

| Resource | Purpose |
|----------|---------|
| `kubernetes_namespace` (`production`, `staging`) | Ensures the namespaces exist before Argo CD/application manifests land |
| `kubernetes_manifest.header_middleware` | Declarative Traefik `Middleware` objects for security / cache headers |
| `kubernetes_manifest.ingress_route` | Per-host Traefik routing that targets the correct backend service (oauth2-proxy or app) |
| `module "<name>"` | Wrapper around `oauth2/modules/traefik_site`, which builds IngressRoute + optional forward-auth |

Traefik runs as part of the platform cluster. These manifests assume the CRDs (`traefik.io/v1alpha1`) are already installed (they are deployed with the Traefik Helm release owned elsewhere).

---

## Prerequisites

* Traefik CRDs present in the cluster (`kubectl api-resources | grep traefik` should list `ingressroutes`, `middlewares`, etc.).
* `kubectl` configured for the target cluster.
* `tofu` initialised in this directory.

---

## Quick Start

```bash
cd platform/traefik-sites
cp terraform.tfvars.example terraform.tfvars   # if you plan to customise
tofu init
tofu plan
tofu apply
```

The provided configuration creates routes for:

* `cervical-screening.pythonaisolutions.com` (production app, hits the upstream service directly)
* `staging.cervical-screening.pythonaisolutions.com`
* `mlflow.cervical-screening.pythonaisolutions.com` (terminates at oauth2-proxy)

---

## Adding a New Host

1. Define the desired module call in `main.tf`, e.g.:

   ```hcl
   module "my_service" {
     source            = "../../oauth2/modules/traefik_site"
     name              = "my-service"
     namespace         = "my-namespace"
     host              = "my-service.example.com"
     proxy_service_name = "oauth2-proxy"      # or null to hit the upstream app directly
     upstream_service_name = "my-service"     # required when routing straight to the app
     upstream_service_port = 8080
     tls_cert_resolver = "letsencrypt"
   }
   ```

2. Ensure the namespace exists (either via this stack or elsewhere).
3. Run `tofu plan` / `tofu apply`.
4. Confirm the IngressRoute:

   ```bash
   kubectl get ingressroute -n my-namespace my-service-ingress
   ```

If the route targets oauth2-proxy, make sure the corresponding oauth2-proxy Service/Deployment exists (managed by `platform/mlflow` or another stack).

---

## Validation & Troubleshooting

| Check | Command | Expectation |
|-------|---------|-------------|
| Ingress routes | `kubectl get ingressroute -A` | Routes exist for production, staging, and mlflow |
| Middlewares | `kubectl get middleware -A` | Header middlewares present in each namespace |
| DNS/Certs | `kubectl describe ingressroute <name>` | TLS resolver set, no errors in events |

Common issues:

* **404s through Traefik** – Verify the backend Service exists and the namespace labels match the module settings.
* **TLS not provisioning** – Check Traefik logs for ACME errors; ensure the cert resolver name matches Traefik’s configuration.
* **Forward-auth failures** – When routing to an upstream service (`root_route_backend = "upstream"`), ensure oauth2-proxy is ready and the middleware is referenced correctly.

---

## Maintenance

* Update header policies in one place (`local.common_header_middlewares`) to propagate to all routes.
* Keep hostnames in sync with DNS; changes to the public domain should be reflected here first.
* When decommissioning a site, remove the module block and run `tofu apply` to clean up the Traefik objects.

Everything in this directory is orthogonal to application deployments—treat it as the canonical definition of how traffic enters the cluster.
