# MLflow Platform Stack

This directory owns every piece of the MLflow deployment that runs in the `mlflow` namespace:

* a single‑instance PostgreSQL database (backed by a persistent volume)
* the upstream MLflow tracking server (with GCS artefact storage)
* oauth2‑proxy protecting ingress with Google OAuth
* all supporting secrets, service accounts, and routing

By keeping the configuration here, the platform repo can recreate the environment end‑to‑end with a single `tofu apply`.

---

## Architecture

| Component | Purpose | Managed By |
|-----------|---------|------------|
| `kubernetes_namespace` + SA | Namespace isolation and default service account | Terraform (`main.tf`) |
| `postgres` Deployment + PVC (`postgres-data`) | MLflow metadata store | Terraform (`main.tf`) |
| `mlflow` Deployment + PVC (`mlflow-data`) | MLflow tracking server (logs + artifact cache) | Terraform (`main.tf`) |
| `oauth2_proxy` module | oauth2-proxy Deployment/Service/Secret | Terraform (reusing `oauth2/modules/oauth2_proxy`) |
| `traefik_site` module | Traefik IngressRoute + TLS | Terraform (`platform/traefik-sites`) |
| `gcs-credentials` secret | Grants MLflow access to `gs://pythonaisolutions-mlflow-artifacts/mlflow` | Manual `kubectl create secret …` (mounted by Terraform) |

The MLflow server is launched with `--serve-artifacts` and `--allowed-hosts mlflow.cervical-screening.pythonaisolutions.com`, so all HTTP access must arrive through oauth2-proxy / Traefik.

---

## Prerequisites

* `kubectl` configured with credentials for the target cluster (`kubectl config current-context` should match the desired GKE cluster).
* `tofu` (OpenTofu ≥ 1.5) for infrastructure changes.
* Access to the Google project to create OAuth client IDs.
* Access to update/create the secrets listed below (or a vault to populate them automatically).

### Secrets & Required Values

| Secret / Variable | Description | Source |
|-------------------|-------------|--------|
| `gcs-credentials` (K8s) | Service account JSON with Storage write access to `gs://pythonaisolutions-mlflow-artifacts/mlflow` | Create manually: `kubectl create secret generic gcs-credentials --namespace mlflow --from-file=key.json=/path/to/sa.json` |
| `postgres_user`, `postgres_password`, `postgres_database` | Credentials for the metadata DB | Define in `terraform.tfvars` (Terraform will create/update the secret) |
| `oauth2_client_id`, `oauth2_client_secret` | Google **Web** client used by oauth2-proxy | Google Cloud Console → OAuth 2.0 Web Client |
| `oauth2_cookie_secret` | 32‑byte random string for oauth2-proxy cookies | Generate once (e.g. `python - <<'PY'` snippet) or reuse existing |
| `oauth2_desktop_client_id` | Google **Desktop** client for notebooks/CLI | Google Cloud Console → OAuth 2.0 Desktop Client |

> ⚠️ Keep `terraform.tfvars` (or any secrets file) out of version control. If you need to share config, use your secrets manager or commit only the `.example`.

---

## Quick Start

1. Ensure prerequisites are in place (kubectl context, tofu, secrets).
2. Copy the sample variables and populate real values:

   ```bash
   cd platform/mlflow
   cp terraform.tfvars.example terraform.tfvars
   # edit terraform.tfvars with the credentials above
   ```

3. Initialise and apply:

   ```bash
   tofu init
   tofu plan   # optional but recommended
   tofu apply
   ```

4. Validate the cluster deployment:

   ```bash
   # Smoke test against the in-cluster MLflow pod
   python platform/mlflow/tests/test_mlflow_internal.py
   ```

   The script:
   * checks `GET /health`
   * logs a throw-away experiment/run via the REST API (ensuring the database and artefact bucket are reachable)

5. Confirm ingress is in place (Traefik plan/apply lives in `platform/traefik-sites`):

   ```bash
   cd ../traefik-sites
   tofu plan
   ```

---

## Regular Operations

### Recreate Everything from Scratch

If you want to prove Terraform can rebuild the environment:

```bash
# optional: take backups if you care about existing data
kubectl delete deployment -n mlflow mlflow postgres
kubectl delete pvc -n mlflow mlflow-data postgres-data

cd platform/mlflow
tofu apply
```

Terraform will recreate both PVCs, the database, and the MLflow server with the correct artefact location (`gs://pythonaisolutions-mlflow-artifacts/mlflow/<experiment_id>`).

### Run the Desktop OAuth Flow

Developers who access MLflow from workstations/notebooks can use the helper script:

```bash
python platform/mlflow/tests/test_desktop_oauth.py
```

It prompts for Google login (using the desktop client secret), hits `/health`, and lists experiments via the public endpoint. Install the prerequisites locally (`pip install mlflow google-auth-oauthlib requests urllib3`).

### Using MLflow from Notebooks / Scripts

```python
from google_auth_oauthlib.flow import InstalledAppFlow
import mlflow, os

# Authenticate (desktop client JSON created above)
flow = InstalledAppFlow.from_client_secrets_file(
    "client_secret_...desktop.json",
    scopes=["openid", "email", "profile"],
)
creds = flow.run_local_server(port=0)

os.environ["MLFLOW_TRACKING_URI"] = "https://mlflow.cervical-screening.pythonaisolutions.com"
os.environ["MLFLOW_TRACKING_TOKEN"] = creds.id_token

# Always create/select an experiment with an explicit artefact location
mlflow.set_experiment(
    experiment_name="ignite-notebook-demo",
    artifact_location="gs://pythonaisolutions-mlflow-artifacts/mlflow/ignite-notebook-demo",
)

with mlflow.start_run():
    mlflow.log_metric("accuracy", 0.92)
```

Setting the experiment ensures your runs do not fall back to `Default` (which would inherit whatever artefact path it had when the server was first created).

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `Invalid Host header - possible DNS rebinding attack detected` | Requests aimed at the service ClusterIP without the public host header | Include `Host: mlflow.cervical-screening.pythonaisolutions.com` when accessing internally, or go through oauth2-proxy |
| MLflow pods crash on startup with `password authentication failed` | `postgres-secret` contains stale credentials | Update `terraform.tfvars` with the intended values and rerun `tofu apply` (Terraform recreates the secret and restarts the deployment) |
| Notebook artefacts land in `gs://YOUR_BUCKET/YOUR_PREFIX` | Default experiment created in an old environment | Create/select a new experiment with a real artefact location, or rebuild the stack so `Default` is recreated (delete PVCs + apply) |
| oauth2-proxy login fails | Incorrect OAuth client values or cookie secret length | Verify the Web client ID/secret and ensure `oauth2_cookie_secret` is exactly 16/24/32 bytes (Base64‑encode before storing) |

Run `python platform/mlflow/tests/test_mlflow_internal.py` after any change; it will highlight database or artefact issues immediately.

---

## Maintenance Checklist

* **Rotate credentials** – update the secrets in `terraform.tfvars` and apply. Terraform will roll the deployments.
* **Upgrade MLflow** – bump the `mlflow_image` variable (default `ghcr.io/mlflow/mlflow:latest`) and apply.
* **Upgrade oauth2-proxy** – override `oauth2_image` in `terraform.tfvars` if you need a newer release.
* **Vendor notebooks/tests** – keep `platform/mlflow/tests/` up to date; they double as documentation for humans and AI agents.

---

## Notes for Future Contributors

* `terraform.tfvars` is intentionally ignored—do not commit secrets. Mirror any structural changes into `terraform.tfvars.example`.
* If you add new experiments or automation via Argo CD, ensure the artefact location is always rooted under `gs://pythonaisolutions-mlflow-artifacts/mlflow` so Terraform and runtime remain aligned.
* After structural changes, always run the smoke test and include command outputs in PR descriptions to signal that the environment still works.
