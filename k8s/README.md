# Kubernetes Single-Node Cluster Setup

This OpenTofu/Terraform stack bootstraps a single-node Kubernetes cluster on a remote Debian host using kubeadm, containerd, and essential add-ons.

## Prerequisites

- SSH access to a fresh Debian host with passwordless sudo
- OpenTofu ≥ 1.5.0 (or Terraform ≥ 1.0)
- `kubectl` installed locally
- Outbound internet connectivity from the target host
- **SSH agent running with keys loaded** (for authentication)

### SSH Agent Setup

This configuration uses SSH agent for authentication (supports passphrase-protected keys):

```bash
# Verify SSH agent is running
ssh-add -L

# If no keys are listed, add them:
ssh-add ~/.ssh/id_rsa           # Your main key
ssh-add ~/.ssh/jumpproxy        # Your bastion key (if using)

# Verify keys are loaded
ssh-add -L
```

## Components Installed

- **Container Runtime**: containerd with SystemdCgroup
- **Kubernetes**: Single-node control plane via kubeadm (also schedules workloads)
- **CNI**: Cilium (with kube-proxy replacement)
- **Ingress**: Traefik (exposed on host ports 80/443)
- **TLS**: cert-manager with CRD installation
- **Storage**: local-path-provisioner (default StorageClass)

## Quick Start

**⚠️ Important:** SSH keys MUST be loaded in the agent before running (see Prerequisites above).

### Step 1: Generate Configuration

Use the helper script if you have an SSH config entry:

```bash
cd k8s
tofu init

# Ensure SSH keys are loaded
ssh-add -L  # Verify keys are present

# Generate k8s.tfvars from your SSH config
./ssh-config-helper.sh k8s-host

# Review k8s.tfvars if needed
```

Or manually create `k8s.tfvars`:

```bash
cp k8s.tfvars.example k8s.tfvars
# Edit with your values
```

### Step 2: Apply

```bash
tofu apply -var-file=k8s.tfvars
```

### After Successful Apply

```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes -o wide
kubectl get pods -A
```

## Verify Add-ons

```bash
kubectl -n kube-system get ds cilium
kubectl -n traefik get deploy traefik
kubectl -n cert-manager get pods
kubectl get storageclass
```

## Variables

**Note:** Authentication uses SSH agent only. No key path variables are needed.

| Variable | Description | Default |
|----------|-------------|---------|
| `host` | Remote host IP/DNS (required) | - |
| `ssh_user` | SSH username | `sysadmin` |
| `cluster_name` | Kubernetes cluster name | `xps-cluster` |
| `kubernetes_version` | Kubernetes version | `1.30.5` |
| `pod_cidr` | Pod network CIDR | `10.244.0.0/16` |
| `service_cidr` | Service network CIDR | `10.96.0.0/12` |
| `cilium_chart_version` | Cilium Helm chart version | `1.16.3` |
| `traefik_chart_version` | Traefik Helm chart version | `32.1.0` |
| `cert_manager_chart_version` | cert-manager Helm chart version | `v1.16.1` |
| `local_path_provisioner_chart_version` | local-path-provisioner version | `0.0.28` |
| `bastion_host` | Bastion/jump host (optional) | `""` |
| `bastion_user` | Bastion username (optional) | `""` |
| `bastion_port` | Bastion port (optional) | `22` |

## Bastion/Jump Host

If your host requires access through a bastion/jump host:

**Auto-detect from SSH Config (Recommended):**

The `ssh-config-helper.sh` script automatically detects bastion settings from your SSH config's `ProxyCommand`.

**Manual Configuration:**

Add these variables to your `k8s.tfvars`:
```hcl
bastion_host = "jump.example.com"
bastion_user = "ubuntu"
bastion_port = 22
```

**Important:** Ensure the bastion SSH key is loaded in your agent:
```bash
ssh-add ~/.ssh/your_bastion_key
```

## Optional: Let's Encrypt Certificate

To enable automatic TLS certificates:

```bash
tofu apply \
  -var 'acme_email=your-email@example.com' \
  -var 'enable_letsencrypt_staging=false'  # Use 'true' for testing
```

This creates a ClusterIssuer for cert-manager. Use it in your Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"  # or letsencrypt-staging
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - example.com
      secretName: example-tls
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: example-service
                port:
                  number: 80
```

## Port-forward Traefik Dashboard (Optional)

```bash
kubectl -n traefik port-forward deploy/traefik 9000:9000
# Access at http://localhost:9000/dashboard/
```

## Remote State (Optional - Recommended for Teams)

Currently uses local backend (suitable for single-user testing).

For team collaboration, migrate to remote state:

**Quick Setup:**
```bash
cd remote-state-setup
# Follow instructions in README.md
```

**Full Details:** See `OPTIONAL_FEATURES.md` for:
- Remote state backend setup (GCS or S3)
- Join command generation (for multi-node clusters)
- Other optional enhancements

## Troubleshooting

### Check cluster initialization
```bash
kubectl get nodes
kubectl get cs  # Component status
```

### Check CNI (Cilium)
```bash
kubectl -n kube-system get pods -l k8s-app=cilium
kubectl -n kube-system logs -l k8s-app=cilium
```

### Check Ingress (Traefik)
```bash
kubectl -n traefik get all
kubectl -n traefik logs -l app.kubernetes.io/name=traefik
```

### Check cert-manager
```bash
kubectl -n cert-manager get all
kubectl get clusterissuer
```

## Clean Up

To destroy the cluster (this is destructive):
```bash
tofu destroy
```

Note: This will not clean up the Debian host itself. To fully reset, you may need to:
- Run `kubeadm reset` on the host
- Remove `/etc/kubernetes/`, `/var/lib/kubelet/`, `/etc/cni/`
- Restart the host

## Security Notes

- The kubeconfig file contains admin credentials - keep it secure
- Consider implementing RBAC for production use
- Enable audit logging for compliance requirements
- Use network policies to restrict pod-to-pod communication
