# Cervical AI Viewer – Current Cluster Configuration Snapshot

Captured from cluster `gke_midyear-pattern-470017-b8_us-central1_cervical-cancer-screening` while migrating the deployment to GitOps.

## Namespaces

- `production`
- `staging`

## Deployments & Services

Both environments run `deployment.apps/cervical-ai-viewer` backed by the `cervical-ai-viewer` ClusterIP service (port 80 → container port 8000) with the NEG annotation `cloud.google.com/neg: {"ingress":true}`.

- Staging: 1 replica, resource requests 250m / 512Mi, limits 500m / 1Gi, ConfigMap logging set to DEBUG.
- Production: 2 replicas, resource requests 500m / 1Gi, limits 1000m / 2Gi, ConfigMap logging INFO.

## Traefik IngressRoutes (prior to Terraform migration)

- `production/cervical-ai-viewer` → `cervical-screening.pythonaisolutions.com`
- `staging/cervical-ai-viewer` → `staging.cervical-screening.pythonaisolutions.com`

Both use entrypoints `web`, `websecure` and `tls.certResolver = letsencrypt` without attached middlewares.

## Traefik Middlewares

Per-namespace header middlewares observed (not wired to routes yet):

- `frontend-headers`: cache and security headers
- `api-headers`: CORS + cache headers
- `health-check-headers`: no-cache headers
- `static-assets-headers`: long-lived cache headers

These are now recreated via Terraform in `platform/traefik-sites` for reuse.
