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

### Step 1: Initialize (defaults already match the current host)

```bash
cd k8s
tofu init

# Optional: generate terraform.tfvars overrides from your SSH config
./ssh-config-helper.sh debian

# Review terraform.tfvars if you need to override the baked-in defaults
```

### Step 2: Apply

**Simple way (recommended):**
```bash
./apply.sh
```

This wrapper script automatically:
- Syncs custom known_hosts entries (if using `~/.ssh/known_hosts.paijump`)
- Checks SSH agent has keys loaded
- Runs `tofu apply` with the checked-in defaults plus any overrides in `terraform.tfvars`

**Manual way:**
```bash
# If using custom known_hosts file (e.g., for FRP/localhost conflicts)
./sync-known-hosts.sh

# Then apply
tofu apply
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
| `host` | Remote host IP/DNS (defaults to the current FRP/localhost endpoint) | `localhost` |
| `host_port` | SSH port for the remote host | `7006` |
| `ssh_user` | SSH username | `sysadmin` |
| `cluster_name` | Kubernetes cluster name | `k8s` |
| `kubernetes_version` | Kubernetes version | `1.30.5` |
| `pod_cidr` | Pod network CIDR | `10.244.0.0/16` |
| `service_cidr` | Service network CIDR | `10.96.0.0/12` |
| `cilium_chart_version` | Cilium Helm chart version | `1.16.3` |
| `traefik_chart_version` | Traefik Helm chart version | `32.1.0` |
| `cert_manager_chart_version` | cert-manager Helm chart version | `v1.16.1` |
| `local_path_provisioner_chart_version` | local-path-provisioner version | `0.0.28` |
| `bastion_host` | Bastion/jump host (optional) | `3.82.253.109` |
| `bastion_user` | Bastion username (optional) | `newuser` |
| `bastion_port` | Bastion port (optional) | `22` |
| `wireguard_server_public_key` | WireGuard server public key | `""` |
| `debian_allowed_ports` | Firewall allowed ports list | See variables.tf |

## Bastion/Jump Host

If your host requires access through a bastion/jump host:

**Auto-detect from SSH Config (Recommended):**

The `ssh-config-helper.sh` script automatically detects bastion settings from your SSH config's `ProxyCommand`.

**Manual Configuration:**

Add these variables to `terraform.tfvars` (or pass them with `-var` flags):
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
tofu apply
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
tofu apply

# Verify new kubeconfig works
kubectl --kubeconfig=$(pwd)/kubeconfig get nodes

# Update your secure storage
cp k8s/kubeconfig ~/.kube/xps-cluster-config
chmod 600 ~/.kube/xps-cluster-config
```

---

## Kubernetes Security Hardening

This cluster includes multiple security hardening features to protect sensitive operations and data:

### 1. Emergency-Only kubeconfig Access

**IMPORTANT:** Kubeconfig access is restricted to emergencies only.

### Recommended Workflow (Emergency Use Only)

The kubeconfig file represents full cluster-admin access. It should ONLY be used for emergencies:

```bash
# STEP 1: Fetch kubeconfig from Terraform state (emergency only)
tofu apply
# kubeconfig is now at: ./kubeconfig

# STEP 2: Use immediately for emergency troubleshooting
export KUBECONFIG=$(pwd)/kubeconfig
kubectl describe pod <problematic-pod>
kubectl logs <container>
# Fix the emergency issue...

# STEP 3: Delete kubeconfig immediately after emergency
rm k8s/kubeconfig
unset KUBECONFIG
```

### What kubeconfig Grants

The kubeconfig file contains:
- **Full cluster-admin credentials** (can modify anything in cluster)
- **Root access equivalent** to the Kubernetes cluster
- **Complete audit trail** - all actions are logged via API audit logging

### Why Emergency-Only?

1. **Security Risk:** Cluster-admin credentials should have minimal exposure
2. **Audit Trail:** Every action is logged - track who did what
3. **Better Alternative:** Use RBAC for regular access (planned future phase)
4. **Separation of Concerns:** Operators should not have cluster-admin access

### Preferred: RBAC for Team Access (Future)

Instead of sharing kubeconfig, use Kubernetes RBAC:

```bash
# Create role for developers
kubectl create role developer --verb=get,list --resource=pods,deployments,services
kubectl create rolebinding developer-binding --clusterrole=developer --user=john@example.com

# This gives limited, traceable access (NOT full cluster-admin)
```

### Key Difference

| Method | Credentials | Audit | Risk |
|--------|------------|-------|------|
| **kubeconfig (current)** | Full cluster-admin | ✅ Logged | 🔴 High |
| **RBAC (future Phase 2)** | Limited per role | ✅ Logged | 🟢 Low |

### Deletion Checklist

Before moving away from emergency kubeconfig access:

- [ ] kubeconfig is NOT stored in git
- [ ] kubeconfig is NOT in project directories
- [ ] kubeconfig is NOT shared via email/Slack
- [ ] kubeconfig is ONLY used in emergencies
- [ ] All kubeconfig access is logged via audit logs
- [ ] Team is trained on emergency procedure
- [ ] RBAC will be implemented for regular access

---

### 2. SSH Access Hardening

SSH access is now **restricted to WireGuard connections only**. Direct SSH from the internet is blocked.

### SSH Routing Security Model

| Source | Access | How | Verified |
|--------|--------|-----|----------|
| **WireGuard VPN** | ✅ Allowed | Via VPN tunnel (10.99.0.0/24) | iptables rules |
| **Direct Internet** | ❌ Blocked | Firewall rule: TCP 22 from WireGuard only | Confirmed |
| **AWS Bastion** | ✅ Allowed | Via WireGuard peer connection | VPN setup |
| **Local Network** | ❌ Blocked | No local network access configured | Firewall |

### How SSH Access Works

```
You → WireGuard VPN Endpoint (AWS Bastion:51820)
      ↓
     WireGuard Tunnel (encrypted)
      ↓
Debian Host (Internal IP: 10.99.0.2) ← SSH (22) from 10.99.0.0/24 ONLY
```

### Verify SSH→WireGuard Restriction

**Test 1: SSH FROM WireGuard should work**

```bash
# From AWS Bastion (has WireGuard connection):
ssh debian@10.99.0.2
# ✅ Success - you're on WireGuard network
```

**Test 2: SSH FROM Internet should fail**

```bash
# From any non-WireGuard IP:
ssh debian@<debian-host-public-ip>
# ❌ Connection timeout or refused
# This is GOOD - SSH is protected!
```

**Test 3: Check iptables rules on Debian host**

```bash
# SSH to Debian host via WireGuard (see Test 1)
sudo iptables -L INPUT -n | grep -i ssh
# Output should show: TCP dpt:22 ACCEPT from 10.99.0.0/24 only
```

### Security Implications

✅ **What this protects against:**
- Brute force SSH attacks from the internet
- Unauthorized SSH access without VPN
- Direct connection without going through WireGuard
- Exposing SSH directly to public internet

✅ **How it works:**
- Firewall rule (iptables) blocks TCP port 22 except from 10.99.0.0/24
- WireGuard subnet (10.99.0.0/24) is the ONLY allowed source
- All SSH connections must go through WireGuard tunnel
- Every SSH connection is logged via API audit logging

### Configuration Details

**Firewall Rule (iptables):**
```bash
iptables -A INPUT -s 10.99.0.0/24 -p tcp --dport 22 -m comment --comment 'SSH (WireGuard only)' -j ACCEPT
```

**WireGuard Subnet:**
- Debian host: `10.99.0.2`
- Server: `10.99.0.1`
- Network: `10.99.0.0/24`

**Verification Location:**
- Rules file: `/etc/iptables/rules.v4`
- Live rules: `sudo iptables -L -n`

### Troubleshooting

**Q: Can't SSH to Debian host?**
```bash
# Make sure you're on WireGuard VPN:
wg show  # Check on AWS Bastion - should show active connection

# Check peer status:
sudo wg show  # From Debian host

# Verify IP is in 10.99.0.0/24 range:
# Your WireGuard IP should be 10.99.0.x (x = 1-254)
```

**Q: Is SSH really restricted?**
```bash
# From outside WireGuard, try:
nmap -p 22 <debian-ip>
# Should show: 22/tcp filtered (filtered = firewall blocking)

# Never: 22/tcp open (that would be bad!)
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
