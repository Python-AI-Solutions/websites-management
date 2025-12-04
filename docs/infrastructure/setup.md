# Deployment Setup Guide

Complete step-by-step guide to deploy the Kubernetes infrastructure (15-20 minutes).

## Prerequisites

### Required Tools

1. **Terraform** (>= 1.5) or **OpenTofu** (>= 1.5)
   ```bash
   terraform --version
   ```

2. **kubectl** (>= 1.27)
   ```bash
   kubectl version --client
   ```

3. **SSH agent** with keys loaded
   ```bash
   ssh-add -L  # Should list your keys
   ssh-add ~/.ssh/your-key  # Add key if needed
   ```

4. **WireGuard** (optional, for VPN access)
   - macOS: `brew install wireguard-tools`
   - Linux: `sudo apt-get install wireguard wireguard-tools`
   - Windows: https://www.wireguard.com/install/

### AWS Setup

Configure AWS credentials before deployment:

**Option 1: Environment variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**Option 2: AWS credentials file** (`~/.aws/credentials`)
```
[default]
aws_access_key_id = your-access-key
aws_secret_access_key = your-secret-key
```

## Deployment Steps

### Step 1: Clone and Navigate

```bash
git clone https://github.com/yourusername/infrastructure.git
cd infrastructure/k8s
```

### Step 2: Generate WireGuard Keys

If you don't have WireGuard keys, generate them:

```bash
# Generate private key (save somewhere safe)
wg genkey | tee debian-private.key | wg pubkey > debian-public.key

# Generate bastion keys
wg genkey | tee bastion-private.key | wg pubkey > bastion-public.key
```

### Step 3: Configure terraform.tfvars

Copy the example and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and provide:
- `debian_wireguard_private_key` - From step 2
- `bastion_wireguard_private_key` - From step 2
- `bastion_wireguard_public_key` - From step 2
- `frp_token` - Random string for emergency access (e.g., `$(openssl rand -hex 32)`)
- `jump_host_jump_user` - SSH username (e.g., `ubuntu`)
- SSH public keys for your team members
- `jump_host_bootstrap_ssh_cidrs` - Your IP address (e.g., `["1.2.3.4/32"]`)
- `wireguard_peers` - List of team members' WireGuard public keys

See `docs/config.md` for detailed explanations.

### Step 4: Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider and initializes the working directory.

### Step 5: Review the Plan

```bash
terraform plan -out=tfplan
```

Review the output to ensure resources look correct. Common resources:
- 1 EC2 instance (jump host/bastion)
- 1 EC2 instance (Debian host)
- Security groups, VPC, subnets
- WireGuard configuration

### Step 6: Deploy

```bash
./apply.sh
```

Or manually:
```bash
terraform apply tfplan
```

This will:
1. Create AWS infrastructure
2. Configure WireGuard VPN
3. Install Kubernetes components
4. Set up Cilium, Traefik, cert-manager
5. Generate kubeconfig file

**Deployment time:** 10-15 minutes depending on AWS region and internet speed.

### Step 7: Verify Deployment

Once complete, verify the cluster:

```bash
# Set kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Check cluster
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
```

Expected output:
```
NAME                STATUS   ROLES           AGE
debian-k8s-host     Ready    control-plane   2m
```

## Post-Deployment

### Access from WireGuard

To connect via WireGuard VPN:

```bash
# Create a WireGuard config file (~/.config/wireguard/cluster.conf)
# Use the output from terraform apply

# Activate VPN (macOS/Linux)
wg-quick up /path/to/cluster.conf

# Or configure via WireGuard app on Windows/macOS
```

Once connected, you can access the cluster directly:
```bash
kubectl --kubeconfig=kubeconfig get pods -A
```

### Deploy Applications

Access Traefik dashboard (if configured):
```bash
kubectl port-forward -n kube-system svc/traefik 8080:8080
# Visit http://localhost:8080/dashboard/
```

### Monitor Cluster

Check logs and status:
```bash
# Check etcd encryption
kubectl get secrets -A

# View API audit logs (stored on Debian host via WireGuard VPN)
# Replace <DEBIAN_HOST_IP> with your Debian host WireGuard IP (10.99.0.2)
ssh sysadmin@<DEBIAN_HOST_IP> tail -f /var/log/kubernetes/audit.log
```

## Troubleshooting

### SSH Connection Fails

**Problem:** `Permission denied (publickey)`

**Solution:**
```bash
# Ensure SSH agent is running
ssh-add -L

# Add your key if not listed
ssh-add ~/.ssh/your-key

# Verify SSH config
./ssh-config-helper.sh debian
```

### Terraform Apply Fails

**Problem:** Error during `terraform apply`

**Steps:**
```bash
# 1. Check configuration
terraform validate

# 2. Try again with verbose output
TF_LOG=DEBUG terraform apply

# 3. Check AWS credentials
aws sts get-caller-identity

# 4. Review security groups
aws ec2 describe-security-groups
```

### Kubeconfig Not Generated

**Problem:** `kubeconfig` file doesn't exist after deployment

**Solution:**
```bash
# Check Debian host directly
ssh -i ~/.ssh/your-key ubuntu@<bastion-ip> \
  "cat /etc/kubernetes/admin.conf" > kubeconfig

# Or re-run terraform
terraform apply -target=null_resource.get_kubeconfig
```

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check node resources
kubectl top nodes
kubectl top pods -A
```

## Next Steps

1. Review [SECURITY.md](./security.md) for hardening practices
2. Read [ARCHITECTURE.md](./architecture.md) to understand the design
3. Deploy optional services from `platform/` directory
4. Configure your own applications in the cluster

## Support

- **Configuration help**: See [CONFIG.md](./config.md)
- **Security questions**: See [SECURITY.md](./security.md)
- **Architecture details**: See [ARCHITECTURE.md](./architecture.md)
- **Contributing**: See [CONTRIBUTING.md](../CONTRIBUTING.md)

