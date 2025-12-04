# Argo CD Platform Stack

This stack installs Argo CD, provisions its CRDs/on-cluster settings, and declares the `AppProject`/`Application` objects that keep downstream repositories (such as `agentic-cervical-screener`) in sync. Treat this directory as the control plane for everything we want Argo CD to manage inside the cluster.

---

## Architecture Overview

| Component | Purpose | Notes |
|-----------|---------|-------|
| `helm_release.argocd` | Installs the official Argo CD Helm chart into namespace `argocd` | Handles CRDs, repo-server, application-controller, dex, redis, etc. |
| `kubernetes_namespace.argocd` | Creates the namespace (optional via `create_namespace`) | Skip creation when using a pre-provisioned namespace |
| `kubernetes_manifest.app_project` | Defines trust boundaries (allowed source repos / destinations) | Keys are the project names (e.g. `platform`) |
| `kubernetes_manifest.application` | Points at external Git repos and deployment paths | Keys are the Application names (`cervical-viewer-prod`, etc.) |

Argo CD is installed with ingress disabled—Traefik handles exposure. The chart values can be extended via `helm_values` and `helm_set` if you need extra configuration.

---

## Prerequisites

* `kubectl` logged into the target cluster (`kubectl config current-context` should match the GKE cluster).
* `tofu` (OpenTofu) initialised in this directory.
* A GitHub token (or GitHub App credentials) with read access to the repositories you plan to onboard; Argo CD requires these for private repos.

---

## Quick Start

1. Populate or update `terraform.tfvars`:

   ```hcl
   namespace = "argocd"

   app_projects = {
     platform = {
       description  = "Platform-managed workloads"
       source_repos = [
         "https://github.com/example-organization/agentic-cervical-screener.git"
       ]
       destinations = [
         { namespace = "production" },
         { namespace = "staging" },
         { namespace = "mlflow" }
       ]
     }
   }

   applications = {
     cervical-viewer-prod = {
       project = "platform"
       source = {
         repo_url = "https://github.com/example-organization/agentic-cervical-screener.git"
         path     = "deploy/k8s/production"
       }
       destination = { namespace = "production" }
       sync_policy = {
         automated = {
           prune     = true
           self_heal = true
         }
       }
     }
   }
   ```

2. Initialise and install CRDs the first time:

   ```bash
   tofu init
   tofu apply -target=helm_release.argocd -auto-approve
   ```

3. Apply the full configuration:

   ```bash
   tofu plan
   tofu apply
   ```

4. Create repository credentials so Argo CD can clone private repos:

   ```bash
   kubectl create secret generic repo-agentic-cervical-screener \
     --namespace argocd \
     --from-literal=url=https://github.com/example-organization/agentic-cervical-screener.git \
     --from-literal=username=<github-username> \
     --from-literal=password=<github-token> \
     --dry-run=client -o yaml | kubectl apply -f -

   kubectl label secret repo-agentic-cervical-screener \
     -n argocd \
     argocd.argoproj.io/secret-type=repository \
     --overwrite
   ```

   You can also run `argocd repo add` after port-forwarding the API server; it will create the same secret.

5. Log in (optional but recommended once the chart is up):

   ```bash
   kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:80
   argocd login localhost:8080 --username admin --password <initial-password>
   argocd app list
   ```

   Change the admin password and configure SSO/OIDC to meet your security requirements.

---

## Making Changes

1. **Add a repo / application** – extend the `applications` map in `terraform.tfvars`; the key becomes the Argo CD Application name. If the repo is private, add or update the repo secret (above).
2. **Adjust trust boundaries** – edit `app_projects`; you can scope `destinations` to specific namespaces or clusters.
3. **Helm customisation** – set `helm_values` or `helm_set` variables to tweak the chart (e.g. enable the Argo CD ingress, tweak resource limits, etc.).
4. **Run `tofu plan` + `tofu apply`** – Argo CD will converge on the new state.

Keep in mind that Argo CD Applications are reconciled by name; renaming them will destroy / recreate the Application object.

---

## Validation & Troubleshooting

| Check | Command | Expectation |
|-------|---------|-------------|
| Argo pods | `kubectl get pods -n argocd` | All pods `Running` (repo-server, application-controller, dex, redis, server) |
| Applications status | `argocd app list` | `Synced` + `Healthy` for each app |
| Terraform drift | `tofu plan` | `No changes` once everything is applied |

**Common issues**

* `rpc error: repository not found` – ensure the repo secret exists with valid credentials and that the URL in `applications` matches exactly.
* `manifest generation error` – Argo CD couldn’t build the manifests; use `argocd app get <name> --refresh` to pull detailed logs.
* Helm upgrade stuck during CRD install – the chart installs CRDs by default. On brand-new clusters run the targeted apply (`-target=helm_release.argocd`) before applying the rest of the resources.

---

## Maintaining the Stack

* **Upgrade Argo CD** – change `helm_chart_version` (and adjust values) then `tofu apply`.
* **Rotate repo credentials** – update the Kubernetes secret or run `argocd repo add` again; Terraform does not store credentials.
* **Audit applications** – guard against drift by keeping `terraform.tfvars` authoritative. If a team needs a new app, add it here rather than via the UI.
* **Exports for documentation** – when onboarding new repos, update this README or add a note under `docs/` so future engineers know why a destination/repo was allowed.

By codifying the Argo CD control plane here we keep the GitOps story clean: every Application and trust boundary goes through review, and the platform team retains visibility over what is reconciling inside the cluster.
