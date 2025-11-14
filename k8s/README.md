# Kubernetes Single-Node Cluster Setup

This OpenTofu/Terraform stack bootstraps a single-node Kubernetes cluster on a remote Debian host using kubeadm, containerd, and essential add-ons.

## Prerequisites

- SSH access to a fresh Debian host with passwordless sudo
- OpenTofu ≥ 1.5.0 (or Terraform ≥ 1.0)
- `kubectl` installed locally
- Outbound internet connectivity from the target host
- **SSH agent running with keys loaded** (for authentication)
- **WireGuard configured** (see [WIREGUARD_SETUP.md](./WIREGUARD_SETUP.md) for details)

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

**Simple way (recommended):**
```bash
./apply.sh
```

This wrapper script automatically:
- Syncs custom known_hosts entries (if using `~/.ssh/known_hosts.paijump`)
- Checks SSH agent has keys loaded
- Runs `tofu apply -var-file=k8s.tfvars`

**Manual way:**
```bash
# If using custom known_hosts file (e.g., for FRP/localhost conflicts)
./sync-known-hosts.sh

# Then apply
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
| `wireguard_server_public_key` | WireGuard server public key | `""` |
| `debian_allowed_ports` | Firewall allowed ports list | See variables.tf |

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

## Troubleshooting

### SSH Authentication Failures

**Problem:** `SSH authentication failed` or `no supported methods remain`

**Solution:** Ensure SSH keys are loaded in agent:
```bash
ssh-add -l  # Check loaded keys
ssh-add ~/.ssh/id_rsa
ssh-add ~/.ssh/jumpproxy
```

### Known Hosts Conflicts (localhost/FRP users)

**Problem:** `REMOTE HOST IDENTIFICATION HAS CHANGED` for localhost

**Why this happens:** If you're using FRP (Fast Reverse Proxy) or multiple jump proxies forwarding to localhost, different services create conflicting host key entries.

**Solution:** Use the wrapper script which handles this automatically:
```bash
./apply.sh
```

Or manually sync your custom known_hosts:
```bash
./sync-known-hosts.sh
tofu apply -var-file=k8s.tfvars
```

**Manual fix:**
```bash
# Remove conflicting entry
ssh-keygen -R localhost

# Re-accept the host key
ssh -o StrictHostKeyChecking=accept-new <your-ssh-alias>
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

## Kubeconfig Management

### Automatic Generation

After successful `tofu apply`, the kubeconfig is automatically fetched from the Kubernetes host:

```bash
# kubeconfig is automatically placed in:
./kubeconfig

# Use it with kubectl:
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

### ⚠️ SECURITY: Never Commit kubeconfig to Git

The kubeconfig file contains **full cluster-admin credentials**. It must NEVER be committed to git.

**Protection in place:**
```bash
# Check: kubeconfig patterns are in .gitignore
grep kubeconfig .gitignore
```

**If accidentally committed, remove from history:**
```bash
# Remove from git tracking
git rm --cached k8s/kubeconfig

# Clean git history (only if not shared with others)
git filter-repo --path k8s/kubeconfig --invert-paths
```

### Secure kubeconfig Storage

**Local Storage (Recommended):**
```bash
# Create secure directory
mkdir -p ~/.kube
chmod 700 ~/.kube

# Store kubeconfig securely
cp k8s/kubeconfig ~/.kube/xps-cluster-config
chmod 600 ~/.kube/xps-cluster-config

# Use it
export KUBECONFIG=~/.kube/xps-cluster-config
kubectl get nodes
```

**Sharing with Team Members:**

❌ **WRONG:**
```bash
git push kubeconfig  # DON'T DO THIS
zip -r project.zip . # Contains kubeconfig!
```

✅ **RIGHT:**
```bash
# Share via secure channel (not git, not email)
# Option 1: Slack/Teams (with ephemeral message)
# Option 2: 1Password/Vault
# Option 3: Secure file sharing (Tresorit, Sync.com)

# Recipient should:
mkdir -p ~/.kube
# Place kubeconfig in ~/.kube/config or custom path
chmod 600 ~/.kube/config
```

### Multiple kubeconfigs

If managing multiple clusters:

```bash
# Keep separate configs
~/.kube/xps-cluster-config
~/.kube/production-cluster
~/.kube/staging-cluster

# Use KUBECONFIG env var to merge or switch
export KUBECONFIG=~/.kube/xps-cluster-config:~/.kube/production-cluster
kubectl config get-contexts
```

### Rotating kubeconfig

When kubeconfig expires or needs rotation:

```bash
# Re-run terraform to fetch new kubeconfig
tofu apply -var-file=k8s.tfvars

# Verify new kubeconfig works
kubectl --kubeconfig=$(pwd)/kubeconfig get nodes

# Update your secure storage
cp k8s/kubeconfig ~/.kube/xps-cluster-config
chmod 600 ~/.kube/xps-cluster-config
```

---

## Security Notes

- **kubeconfig file contains admin credentials** - Keep it secure, NEVER commit to git
- **Local storage:** `~/.kube/xps-cluster-config` with `chmod 600`
- **Sharing:** Use secure channels only, NOT git or email
- Consider implementing RBAC for production use (defers cluster-admin access to non-admin users)
- Enable audit logging for compliance requirements
- Use network policies (Cilium) to restrict pod-to-pod communication
- Rotate kubeconfig periodically (at least annually)
