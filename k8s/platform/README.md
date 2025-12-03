# Optional Platform Services

This directory contains optional add-on services for the Kubernetes cluster. These are **not included in the main deployment** and serve as examples for additional functionality.

## Services

### 1. **ArgoCD** (`argocd/`)

GitOps continuous deployment tool for managing Kubernetes applications.

**Status**: Example configuration - ready to deploy when needed

**What it provides**:
- Git-based deployment automation
- Application lifecycle management
- Multi-cluster support
- RBAC and SSO integration

**How to deploy**:
```bash
cd platform/argocd
tofu init
tofu plan -var-file=terraform.tfvars
tofu apply
```

**Note**: Requires configuring Git repository access and authentication

---

### 2. **MLflow** (`mlflow/`)

Machine Learning Flow tracking server for experiment management and artifact storage.

**Status**: Example implementation - not production-ready in current form

**What it provides**:
- Experiment tracking and comparison
- Model registry
- Artifact storage (GCS integration)
- OAuth2 authentication via oauth2-proxy

**Why not included in main deployment**:
- Requires GCP/GCS setup and service account keys
- OAuth2 configuration is environment-specific
- PostgreSQL backend requires database management
- Not essential for core infrastructure

**How to use this as reference**:
1. Review `mlflow/main.tf` for Kubernetes deployment patterns
2. Check `mlflow/README.md` for detailed configuration
3. Adapt to your environment by:
   - Setting up GCS bucket for artifacts
   - Creating service account with appropriate permissions
   - Configuring OAuth2 client ID/secret
   - Providing PostgreSQL credentials

**Future deployment**:
When you're ready to add MLflow:
```bash
cd platform/mlflow
# Configure terraform.tfvars with your values
tofu init
tofu plan
tofu apply
```

---

### 3. **Traefik Sites** (`traefik-sites/`)

Ingress routing and TLS termination configuration.

**Status**: Supporting module - used by other services

**What it provides**:
- IngressRoute definitions for services
- Automatic TLS certificate management
- Path-based and host-based routing

**How it's used**:
- Referenced by ArgoCD and MLflow configurations
- Manages Traefik middleware and routing rules
- Handles cert-manager integration

---

## Adding Services to Your Cluster

### Prerequisites
- Main Kubernetes cluster deployed and running
- `kubectl` configured with cluster access
- OpenTofu/Terraform initialized

### General Process

1. **Configure service-specific variables**:
   ```bash
   cd platform/<service>
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. **Review what will be deployed**:
   ```bash
   tofu plan
   ```

3. **Deploy the service**:
   ```bash
   tofu apply
   ```

4. **Verify deployment**:
   ```bash
   kubectl get pods -n <service-namespace>
   kubectl logs -n <service-namespace> <pod-name>
   ```

### Removing Services

If you need to remove a service:

```bash
cd platform/<service>
tofu destroy
```

This will cleanly remove all Kubernetes resources created by Terraform.

---

## Security Considerations

### Secrets Management
- Never commit `terraform.tfvars` files
- Use `.gitignore` to protect local configuration
- Consider using Terraform Cloud/Vault for sensitive values
- Keep service account keys in secure location

### Network Access
- Services are accessible through Traefik ingress
- Protect access with authentication (OAuth2, etc.)
- Review network policies for service isolation
- Use RBAC to limit service account permissions

---

## Troubleshooting

### Service fails to deploy
```bash
# Check Terraform errors
tofu plan

# Check Kubernetes events
kubectl describe pod -n <namespace> <pod-name>

# Check logs
kubectl logs -n <namespace> <pod-name>
```

### Can't access service
- Verify Traefik ingress is configured
- Check DNS resolution for service hostname
- Verify TLS certificate is valid
- Review authentication configuration

### Secrets not mounted
- Verify Kubernetes secret exists: `kubectl get secrets -n <namespace>`
- Check secret volume mounts in pod spec
- Verify secret keys match environment variable names

---

## References

- **ArgoCD**: https://argoproj.github.io/cd/
- **MLflow**: https://mlflow.org/
- **Traefik**: https://traefik.io/
- **Terraform Kubernetes Provider**: https://registry.terraform.io/providers/hashicorp/kubernetes/latest

---

## Contributing

To improve or add services:

1. Keep configuration modular and self-contained
2. Include comprehensive README in service directory
3. Provide `terraform.tfvars.example` with all required variables
4. Document dependencies and prerequisites
5. Test thoroughly before submitting changes

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

---

## Support

For issues with platform services, check the individual service READMEs first, then consult the main [SECURITY.md](../SECURITY.md) and [SETUP.md](../SETUP.md) guides.
