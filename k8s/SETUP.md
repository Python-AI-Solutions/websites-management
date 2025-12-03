# Kubernetes Infrastructure Setup Guide

## Overview

This repository contains infrastructure-as-code for deploying a production Kubernetes cluster with:
- **Jump Host (Bastion):** EC2 instance with SSH access and WireGuard VPN
- **Debian Host:** Private host connected via WireGuard, runs Kubernetes control plane
- **Kubernetes Cluster:** Single-node cluster with Cilium CNI, Traefik ingress, and cert-manager

All infrastructure is managed with Terraform and can be deployed in minutes.

---

## Prerequisites

### Required Tools

1. **Terraform** (>= 1.5)
   ```bash
   terraform --version
   ```

2. **kubectl** (>= 1.27)
   ```bash
   kubectl version --client
   ```

3. **WireGuard** (for VPN access)
   - macOS: `brew install wireguard-tools`
   - Linux: `sudo apt-get install wireguard wireguard-tools`
   - Windows: Download from https://www.wireguard.com/install/

4. **SSH Agent** (with your SSH keys loaded)
   ```bash
   ssh-add -l  # Should show your keys
   ```

5. **AWS CLI** (optional, for debugging)
   ```bash
   aws --version
   ```

### AWS Credentials

Set up AWS credentials before deployment:

```bash
# Option 1: Environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Option 2: AWS credentials file (~/.aws/credentials)
[default]
aws_access_key_id = your-access-key
aws_secret_access_key = your-secret-key
```

### WireGuard Key Pairs

Generate WireGuard keys for Debian host and bastion:

```bash
# For Debian host
wg genkey | tee debian.key | wg pubkey > debian.pub

# For bastion (server)
wg genkey | tee bastion.key | wg pubkey > bastion.pub

# For your laptop/client
wg genkey | tee laptop.key | wg pubkey > laptop.pub
```

### SSH Public Keys

Get your SSH public key:

```bash
cat ~/.ssh/id_ed25519.pub
# or
cat ~/.ssh/id_rsa.pub
```

---

## Configuration

### 1. Create terraform.tfvars

Copy the example configuration and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:

```hcl
# Your WireGuard private keys (from above)
debian_wireguard_private_key  = "base64_encoded_key"
bastion_wireguard_private_key = "base64_encoded_key"
bastion_wireguard_public_key  = "your_bastion_public_key"

# Your SSH public key
jump_host_jump_user_public_key = "ssh-ed25519 AAAA... your@machine"
jump_host_admin_authorized_key = "ssh-ed25519 AAAA... admin@machine"

# Your source IP (for Terraform deployment)
jump_host_bootstrap_ssh_cidrs = ["YOUR.IP.ADDRESS/32"]

# WireGuard peers (add your clients)
wireguard_peers = [
  {
    name       = "debian-host"
    public_key = "your_debian_pub_key"
    allowed_ips = ["10.99.0.2/32"]
    persistent_keepalive = 25
  },
  {
    name       = "your-laptop"
    public_key = "your_laptop_pub_key"
    allowed_ips = ["10.99.0.15/32"]
    persistent_keepalive = 25
  }
]

# Other settings
control_plane_endpoint = "192.168.1.123:6443"
bastion_ssh_user = "your-username"
enable_frp_emergency = true
deploy_debian_host = true
deploy_kubernetes_cluster = true
```

### 2. Initialize Terraform

```bash
terraform init
```

This will:
- Download required providers (AWS, Kubernetes, Helm)
- Initialize remote state backend (GCS)
- Create .terraform directory

---

## Deployment

### Plan the Deployment

Review what Terraform will create:

```bash
terraform plan
```

This will show all resources to be created/modified/destroyed.

### Apply Configuration

Deploy the infrastructure:

```bash
./apply.sh
```

Or manually:

```bash
terraform apply
```

**Expected deployment time:** 15-20 minutes

The process will:
1. Create EC2 jump host with security groups
2. Set up WireGuard on jump host
3. Configure Debian host via SSH
4. Initialize Kubernetes cluster
5. Deploy Cilium, Traefik, cert-manager
6. Output kubeconfig file

### Monitor Deployment

Watch the Terraform output for progress:

```bash
# In another terminal, check jump host SSH
ssh ec2-user@YOUR_BASTION_IP

# Check WireGuard status
wg show

# Watch kubeadm logs
sudo kubeadm logs kubernetes
```

---

## Post-Deployment

### 1. Configure WireGuard Client

Create WireGuard configuration on your machine:

```bash
# macOS
sudo wg-quick up laptop.conf

# Linux
sudo wg-quick up laptop.conf

# Manual (all platforms)
# Edit /etc/wireguard/laptop.conf with:
[Interface]
Address = 10.99.0.15/24
PrivateKey = YOUR_LAPTOP_PRIVATE_KEY
DNS = 8.8.8.8

[Peer]
PublicKey = BASTION_PUBLIC_KEY
Endpoint = BASTION_PUBLIC_IP:51820
AllowedIPs = 10.99.0.0/24, 192.168.1.0/24
PersistentKeepalive = 25
```

### 2. Access Kubernetes Cluster

Once WireGuard is connected:

```bash
# Copy kubeconfig from output
export KUBECONFIG=/path/to/k8s/kubeconfig

# Test access
kubectl get nodes
kubectl get pods -A
```

### 3. Verify Cluster Components

Check that all components are running:

```bash
# Cilium CNI
kubectl get ds -n kube-system cilium

# Traefik Ingress
kubectl get deploy -n traefik traefik

# cert-manager
kubectl get deploy -n cert-manager cert-manager

# local-path-provisioner
kubectl get deploy -n local-path-storage local-path-provisioner
```

### 4. Set Up Ingress

Create your first ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 8080
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls
```

---

## Accessing the Cluster

### Via WireGuard + SSH

**Option 1: Direct SSH to Debian host**

```bash
# Assumes WireGuard is connected
ssh -i ~/.ssh/id_ed25519 user@192.168.1.123 kubectl get nodes
```

**Option 2: Proxy through bastion**

```bash
# SSH config
Host jump-host
  HostName YOUR_BASTION_PUBLIC_IP
  User ec2-user
  IdentitiesOnly yes

Host kube-host
  HostName 192.168.1.123
  User root
  ProxyJump jump-host
  IdentitiesOnly yes

# Then use
ssh kube-host kubectl get nodes
```

### Via kubectl

```bash
# Set kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Use kubectl normally
kubectl get nodes
kubectl get pods -A
kubectl logs -f deployment/myapp -n default
```

---

## Troubleshooting

### WireGuard Connection Issues

```bash
# Check WireGuard status
wg show

# Check if you can reach Kubernetes node
ping 10.99.0.2
ping 192.168.1.123

# Check routing
route -n | grep 10.99

# On bastion, check WireGuard config
ssh ec2-user@BASTION_IP
sudo wg show
```

### Kubernetes Cluster Issues

```bash
# SSH to Debian host via bastion
ssh -J ec2-user@BASTION_IP user@192.168.1.123

# Check kubeadm logs
sudo journalctl -u kubelet -n 50

# Check cluster status
sudo kubeadm init status
kubectl get nodes -o wide

# Check API server health
kubectl get componentstatus
```

### SSH Connection Issues

```bash
# Check SSH agent has keys
ssh-add -l

# Manually specify key
ssh -i ~/.ssh/id_ed25519 ec2-user@BASTION_IP

# Enable SSH debug
ssh -vvv ec2-user@BASTION_IP

# Check bastion security group allows SSH
aws ec2 describe-security-groups --group-ids sg-xxx
```

### Terraform State Issues

```bash
# View remote state
terraform state list
terraform state show aws_instance.jump_host

# Pull remote state locally
terraform refresh

# If state is corrupted
terraform state rm resource_name  # Caution!
terraform import resource_name id
```

---

## Cleanup

To destroy all infrastructure:

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy everything
terraform destroy
```

**Warning:** This will delete:
- EC2 instances
- Security groups
- Elastic IPs
- All Kubernetes workloads and data

---

## Advanced Configuration

### Customize Variables

Edit `variables.tf` to change:

```hcl
# Kubernetes version
kubernetes_version = "1.28.0"

# Instance type
jump_host_instance_type = "t3.medium"

# Network ranges
pod_cidr = "10.244.0.0/16"
service_cidr = "10.96.0.0/12"

# Helm chart versions
cilium_chart_version = "1.14.0"
traefik_chart_version = "25.0.0"
```

### Add More WireGuard Peers

Add to `wireguard_peers` in `terraform.tfvars`:

```hcl
wireguard_peers = [
  # ... existing peers ...
  {
    name                 = "new-peer"
    public_key           = "NEW_PEER_PUBLIC_KEY"
    allowed_ips          = ["10.99.0.20/32"]
    persistent_keepalive = 25
  }
]
```

Then apply:

```bash
terraform apply
```

### Emergency Access (FRP)

If WireGuard is down, FRP provides emergency SSH tunnel:

```bash
# From the FRP control machine
ssh -R :2222:192.168.1.123:22 frp-server

# Then from anywhere
ssh -p 2222 localhost
```

---

## Security Best Practices

1. **Keep terraform.tfvars private** - Don't commit to version control
2. **Rotate WireGuard keys regularly** - Update in terraform.tfvars and apply
3. **Enable API audit logging** - Kubernetes API calls are logged to `/var/log/kubernetes/audit.log`
4. **Restrict bootstrap CIDRs** - Only allow your IP in `jump_host_bootstrap_ssh_cidrs`
5. **Use strong FRP tokens** - Change `frp_token` to a strong random string
6. **Monitor cluster access** - Review audit logs and watch for unusual activity

---

## Additional Resources

- **Terraform Docs:** https://www.terraform.io/docs
- **Kubernetes Docs:** https://kubernetes.io/docs
- **Cilium Network Plugin:** https://docs.cilium.io/
- **Traefik Ingress:** https://doc.traefik.io/traefik/
- **cert-manager:** https://cert-manager.io/docs/
- **WireGuard:** https://www.wireguard.com/

---

## Support & Issues

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review Terraform logs: `TF_LOG=DEBUG terraform apply`
3. Check kubeadm logs: `sudo journalctl -u kubelet`
4. Verify WireGuard connectivity: `wg show && ping 10.99.0.2`
