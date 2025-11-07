# Platform vs. Application Repositories

This workspace acts as the **platform repository**. It owns cluster-wide services, Terraform modules, and GitOps configuration. Individual microservices or UIs live in separate **application repositories**.

## Platform Repository (this repo)

- Provides reusable Terraform modules (`oauth2`, `traefik_site`) and stacks (`mlflow-oauth-setup`, `platform/argocd`, `platform/traefik-sites`).
- Installs and configures shared tooling such as Argo CD, cert-manager, ingress controllers, observability, etc.
- Stores Argo CD `AppProject` and `Application` CRDs that point to external application repos. All platform changes go through PRs here so cluster state is always tracked in Git.

## Application Repositories

- Contain service code, Dockerfiles, Helm charts or Kustomize overlays for that one app.
- CI builds/pushes images and updates manifests (or opens PRs) in the app repo.
- No cluster-scoped resources (e.g., installing Argo, creating namespaces for other teams). They only define what needs to run for that application (e.g., the `deploy/k8s/<environment>` overlays in `agentic-cervical-screener`).

## GitOps Flow with Argo CD

1. Platform repo defines an `Application` in `platform/argocd` that targets an application repo path and namespace.
2. Argo CD watches the application repo; whenever manifests change on the tracked branch, Argo reconciles the cluster.
3. Operations like onboarding a new app, changing OAuth/Traefik defaults, or adjusting RBAC occur in the platform repo. Shipping a new release stays in the app repo.

Keeping these roles distinct prevents accidental cluster-wide changes during feature work and keeps production configuration reviewable.
