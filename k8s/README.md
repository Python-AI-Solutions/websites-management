# Cervical Screening Platform – Repository Guide

This repository houses everything required to operate the cervical-screening platform on Google Cloud:

* **Infrastructure** – OpenTofu (Terraform) stacks for Argo CD, Traefik, MLflow, reusable oauth2-proxy modules, and supporting IAM.
* **Application** – The `agentic-cervical-screener` service with Kubernetes overlays for staging/production.
* **Automation** – Smoke tests, helper scripts, and documentation to keep human and AI contributors aligned.

If you are new to the project, start with the [Quick Start](#quick-start) and then dive into the stack-specific READMEs under `platform/`.

---

## Repository Layout

```
.
├── platform/
│   ├── argocd/          # Argo CD Helm release + AppProject/Application objects
│   ├── mlflow/          # MLflow + Postgres + oauth2-proxy stack (with tests)
│   └── traefik-sites/   # Shared Traefik ingress and middlewares
├── oauth2/              # Reusable oauth2-proxy modules consumed by stacks above
├── agentic-cervical-screener/  # Application source, kustomize overlays, CI helpers
├── docs/                # Additional design notes (platform vs application etc.)
└── scripts/             # Utility scripts used during cluster maintenance
```

Each subdirectory ships its own README describing prerequisites, variables, and validation steps—treat those as the source of truth when working on a specific component.

---

## Prerequisites

| Tool | Purpose | Notes |
|------|---------|-------|
| [OpenTofu](https://opentofu.org/docs/intro/install/) ≥ 1.5 | Infrastructure as code | Required for everything under `platform/` and `oauth2/` |
| `kubectl` | Interact with the GKE cluster | Ensure your kubeconfig contains the target context |
| `gcloud` CLI | Auth + IAM | Useful for bootstrapping credentials and enabling APIs |
| Python 3.10+ | Runs smoke tests (`platform/mlflow/tests/*.py`) | If you need notebook auth scripts, install `mlflow`, `requests`, `google-auth-oauthlib` locally |

### Authentication

For day-to-day operations you typically authenticate with:

```bash
gcloud auth application-default login         # Obtain ADC for OpenTofu
gcloud container clusters get-credentials <cluster> --region us-central1
kubectl config current-context                # Confirm you are pointing at the right cluster
```

If you need to bootstrap a new service account for automation, the legacy Terraform stack in the repository root can still create the “k8s-admin” account—review the comments inside `variables.tf` for required roles/scopes.

---

## Quick Start

1. **Select the stack you want to modify** (e.g. `platform/mlflow`).
2. Copy the sample variables file if needed:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   nano terraform.tfvars   # populate secrets and settings
   ```
3. Run the standard OpenTofu workflow:
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```
4. Execute the provided smoke tests for the component (example for MLflow):
   ```bash
   python platform/mlflow/tests/test_mlflow_internal.py
   ```
5. Commit only structural changes—never commit `terraform.tfvars` or generated secrets.

> Tip: when making sweeping changes (e.g., wiping the MLflow database) delete the relevant deployments/PVCs with `kubectl` first, then run `tofu apply` to ensure Terraform can recreate everything cleanly.

---

## Common Workflows

### Deploying Platform Changes End-to-End

1. Update configuration in the relevant stack (`platform/argocd`, `platform/traefik-sites`, `platform/mlflow`).
2. Run `tofu plan`/`tofu apply` for each stack.
3. Validate:
   * Argo CD: `kubectl get pods -n argocd`, `argocd app list`
   * Traefik: `kubectl get ingressroute -A`
   * MLflow: `python platform/mlflow/tests/test_mlflow_internal.py`
4. Document the change in the stack README or `docs/` if anything operationally significant changed.

### Working on the Application Repo

* Develop locally under `agentic-cervical-screener` with Pixi: `pixi install`, `pixi run dev`.
* Update kustomize overlays under `deploy/k8s/<environment>`.
* Commit changes to the application repository; Argo CD (configured via `platform/argocd`) reconciles them automatically.

### Notebook / Desktop Access to MLflow

* Use `client_secret_...json` (desktop OAuth client) with `platform/mlflow/tests/test_desktop_oauth.py`.
* Always set a named experiment with a valid `artifact_location` (see the MLflow README for examples).

---

## Validation Checklist

Run these commands after major platform changes:

```bash
# Ensure infrastructure state matches
cd platform/argocd && tofu plan
cd ../traefik-sites && tofu plan
cd ../mlflow && tofu plan

# Verify runtime health
kubectl get pods -n argocd
kubectl get pods -n mlflow
python platform/mlflow/tests/test_mlflow_internal.py
```

If any step fails, fix the issue before shipping the change—future team members (human or AI) will rely on a clean baseline.

---

## Contributing Guidelines

1. **Work in the right directory.** Platform stacks live under `platform/`; application-specific changes belong in the app repo.
2. **Keep READMEs current.** If you add steps, variables, or scripts, update the README next to the code.
3. **Avoid committing secrets.** `terraform.tfvars`, service-account JSON, and OAuth client files must remain local or in your secrets manager.
4. **Document manual steps.** Anything that cannot be codified in Terraform should be described under `docs/` or the relevant README so it’s easy to repeat.

---

## Further Reading

* [`docs/platform-vs-application.md`](docs/platform-vs-application.md) – philosophy behind the platform/app split.
* [`platform/argocd/README.md`](platform/argocd/README.md) – Argo CD Helm release details and repository onboarding.
* [`platform/mlflow/README.md`](platform/mlflow/README.md) – MLflow/ Postgres / oauth2-proxy stack with smoke tests.
* [`platform/traefik-sites/README.md`](platform/traefik-sites/README.md) – Traefik ingress patterns and how to add new hostnames.
* [`oauth2/README.md`](oauth2/README.md) – Reusable oauth2-proxy module documentation.
* [`agentic-cervical-screener/README.md`](agentic-cervical-screener/README.md) – Application development and GitOps instructions.

Treat this repository as an evolving runbook—update documents when you learn something new so the next engineer (or AI teammate) can get up to speed quickly.

### 1. Verify Service Account Creation
```bash
# List service accounts to confirm creation
gcloud iam service-accounts list --filter="email:k8s-admin@midyear-pattern-470017-b8.iam.gserviceaccount.com"

# Get service account details
gcloud iam service-accounts describe k8s-admin@midyear-pattern-470017-b8.iam.gserviceaccount.com
```

### 2. Verify IAM Roles Assignment
```bash
# Check all IAM bindings for the service account
gcloud projects get-iam-policy midyear-pattern-470017-b8 \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:k8s-admin@midyear-pattern-470017-b8.iam.gserviceaccount.com"

# Expected output should show exactly:
# - roles/container.admin
# - roles/compute.viewer
# - roles/serviceusage.serviceUsageAdmin
```

### 3. Verify API Enablement
```bash
# Check enabled APIs
gcloud services list --enabled --filter="name:(container.googleapis.com OR compute.googleapis.com)"

# Expected output should show:
# - container.googleapis.com (Kubernetes Engine API)
# - compute.googleapis.com (Compute Engine API)
```

### 4. Test Service Account Authentication
```bash
# Authenticate using the service account
gcloud auth activate-service-account --key-file=k8s-admin-key.json

# Set the project
gcloud config set project midyear-pattern-470017-b8

# Verify you're using the service account
gcloud auth list

# Expected output should show k8s-admin@midyear-pattern-470017-b8.iam.gserviceaccount.com as active
```

### 5. Test Minimal GKE Permissions
```bash
# Test container.admin permissions - these should work:
gcloud container clusters list
gcloud container get-server-config --region=us-central1

# Test compute.viewer permissions - these should work:
gcloud compute zones list
gcloud compute networks list
gcloud compute machine-types list --zones=us-central1-a

# Test serviceusage.serviceUsageAdmin - this should work:
gcloud services list --available --filter="name:container.googleapis.com"
```

### 6. Test Permission Boundaries (Optional)
```bash
# These should FAIL (demonstrating minimal permissions):
gcloud compute instances list  # Should fail - no compute.instances.list permission
gcloud storage buckets list    # Should fail - no storage permissions
gcloud logging logs list       # Should fail - no logging permissions

# If any of these succeed, you may have excessive permissions
```

### 7. Create a Test GKE Cluster
```bash
# Test actual GKE cluster creation (minimal cluster)
gcloud container clusters create verification-cluster \
  --zone us-central1-a \
  --num-nodes 1 \
  --machine-type e2-micro \
  --disk-size 10GB \
  --enable-autorepair \
  --enable-autoupgrade

# Verify cluster creation
gcloud container clusters describe verification-cluster --zone us-central1-a

# Clean up test cluster
gcloud container clusters delete verification-cluster --zone us-central1-a --quiet
```

### Expected Results Summary

✅ **Should Work**:
- List/create/delete GKE clusters
- View compute resources (zones, networks, machine types)
- Enable/disable APIs
- Authenticate with service account

❌ **Should NOT Work** (confirming minimal permissions):
- Create/modify compute instances directly
- Access storage buckets
- View detailed logs
- Manage other GCP services

If verification fails, check:
1. Terraform applied successfully without errors
2. All IAM policy changes have propagated (wait 1-2 minutes)
3. Service account key is correctly downloaded and used

## Outputs

- `service_account_email` - Email of the created service account
- `service_account_key_json` - Service account key in JSON format (sensitive)
- `usage_instructions` - Step-by-step usage instructions

## Cleanup

To remove all created resources:
```bash
tofu destroy
```

## Troubleshooting

### Common Issues

1. **API Not Enabled**: If you get "API has not been used" errors, ensure:
   - `container.googleapis.com` (Kubernetes Engine) is enabled
   - `compute.googleapis.com` (Compute Engine) is enabled
   - Billing is enabled for the project
2. **Insufficient Permissions**: The deploying user account needs permissions to:
   - Create service accounts
   - Assign IAM roles
   - Enable APIs
3. **403 Errors**: After deployment, wait a few minutes for permissions to propagate
4. **Quota Limits**: Check GCP quotas for service accounts and IAM policies

### Getting Help

- Check `tofu plan` output before applying
- Use `tofu output usage_instructions` for setup help
- Verify authentication with `gcloud auth list`

## Security Best Practices

1. Store service account keys securely (use secret management systems)
2. Regularly audit and rotate keys
3. Use Workload Identity for GKE workloads when possible
4. Apply principle of least privilege
5. Monitor service account usage through Cloud Logging
