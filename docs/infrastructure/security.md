# Security Practices

This infrastructure implements multiple security layers for production-grade protection.

## Secret Management

### terraform.tfvars - DO NOT COMMIT

This file contains all secrets and **must never be committed to git**:

```bash
# Verify it's protected
grep terraform.tfvars .gitignore  # Should be present

# Set restrictive permissions
chmod 600 terraform.tfvars
```

**Contents include:**
- WireGuard private keys
- SSH public keys for team members
- FRP authentication token
- AWS key pair name
- WireGuard peer configuration

**Protect this file:**
- Keep locally only
- Don't share in chat/email
- Use separate secrets management for team (Vault, 1Password, etc.)
- Rotate credentials periodically

## Network Security

### WireGuard VPN

All cluster access goes through WireGuard encrypted tunnel:

- **Bastion host** exposes WireGuard endpoint (UDP port 51820)
- **All internal traffic** is encrypted end-to-end
- **SSH access** requires VPN connection first
- **Emergency access** via FRP reverse proxy (isolated channel)

**Setup:**
```bash
# Generate keys (store privately)
wg genkey | wg pubkey

# Add to wireguard_peers in terraform.tfvars
wireguard_peers = [
  { name = "team-member", public_key = "...", allowed_ips = ["10.99.0.X/32"] }
]
```

### SSH Hardening

- **Key-based auth only** (no passwords)
- **Bastion host** requires valid AWS key pair
- **Bootstrap CIDRs** restrict initial deployment to known IPs
- **SSH agent forwarding** for key management

**Access pattern:**
```
Your Machine → SSH Agent → Bastion (jump host) → Kubernetes cluster
```

## Encryption

### At Rest

**Etcd encryption:**
- Algorithm: AES-CBC with 256-bit keys
- Affects: Kubernetes secrets, etcd data
- Key stored securely in `/etc/kubernetes/encryption/`

**Verification:**
```bash
kubectl get secrets -n kube-system
# All secrets are encrypted at rest
```

### In Transit

- **TLS 1.3** for Kubernetes API (port 6443)
- **WireGuard** for all network traffic (UDP 51820)
- **cert-manager** manages internal certificates
- **Let's Encrypt** for public-facing services via Traefik

## Kubernetes Security

### RBAC (Role-Based Access Control)

Default service accounts are restricted:
- Admin user (kubeconfig) → Full access
- Pod service accounts → Limited to their namespace
- External users → Can be configured via kubeadm config

### API Audit Logging

Complete audit trail of all Kubernetes API operations:
- **Location:** `/var/log/kubernetes/audit.log` on Debian host
- **Events logged:** Pod creation, secret access, deployments, etc.
- **Retention:** Kept locally (configure log rotation as needed)

**Access audit logs:**
```bash
# Connect via WireGuard first, then SSH to Debian host
ssh sysadmin@10.99.0.2 tail -f /var/log/kubernetes/audit.log
```

### Network Policies

Implemented via Cilium:
- Pod-to-pod communication restricted to necessary paths
- Egress policies prevent unexpected outbound traffic
- Ingress policies controlled via Traefik

## Emergency Access

### FRP Reverse Proxy

For breakglass scenarios (when normal access fails):

```bash
# FRP client runs on Debian host
# Connects to FRP server for reverse tunnel
# Provides SSH access via alternative channel
```

**Usage:**
```bash
# If normal WireGuard access fails, use FRP tunnel as fallback
# Contact infrastructure admin for FRP port and token
ssh -p <FRP_PORT> frp@<bastion-public-ip>
```

**Security:**
- Requires valid FRP token (in terraform.tfvars)
- Should be monitored for abuse
- Disabled by default (set `enable_frp_emergency = true` to enable)

## AWS Security

### Security Groups

- **Bastion security group:**
  - SSH (22) from `jump_host_bootstrap_ssh_cidrs` only
  - WireGuard (51820) from anywhere (encrypted)

- **Debian host security group:**
  - All traffic from Bastion only
  - No direct internet access
  - No direct SSH access (requires WireGuard)

### IAM

- EC2 instances use minimal IAM policies
- No hardcoded credentials in instances
- AWS credentials come from environment/config file only

## Best Practices

### Daily Operations

1. **Verify cluster health:**
   ```bash
   kubectl cluster-info
   kubectl get nodes
   kubectl top nodes
   ```

2. **Monitor audit logs:**
   ```bash
   # Connect via WireGuard first
   ssh sysadmin@10.99.0.2 tail -100 /var/log/kubernetes/audit.log
   ```

3. **Check certificate expiration:**
   ```bash
   kubectl get certificate -A
   ```

### Secret Rotation

Periodically rotate:
- WireGuard private keys
- SSH keys
- FRP token
- AWS credentials

**Process:**
1. Generate new values
2. Update terraform.tfvars
3. Run `terraform apply`
4. Verify access works
5. Remove old credentials

### Backups

**Critical files to backup:**
- `terraform.tfvars` - All secrets
- `kubeconfig` - Cluster admin credentials
- `/etc/kubernetes/encryption/` - Etcd encryption keys

**Store backups:**
- Encrypted storage (S3, Google Drive, etc.)
- Separate from production
- Version controlled (but not in git)

### Monitoring

Set up monitoring for:
- Failed SSH attempts to bastion
- API errors in audit log
- Pod crashes in critical namespaces
- Network anomalies

## Security Checklist

- [ ] WireGuard keys generated and stored securely
- [ ] terraform.tfvars not committed to git
- [ ] SSH keys loaded in agent before deployment
- [ ] Kubeconfig file protected (chmod 600)
- [ ] Bootstrap CIDRs restricted to known IPs
- [ ] All team SSH keys in wireguard_peers
- [ ] FRP token strong (32+ characters)
- [ ] AWS credentials in environment or ~/.aws/
- [ ] Audit logs monitored regularly
- [ ] Backup strategy in place

## Troubleshooting

### Audit Log Access Fails
```bash
# Connect via WireGuard first (10.99.0.2 is Debian host internal IP)
# Check log file exists
ssh sysadmin@10.99.0.2 ls -la /var/log/kubernetes/audit.log

# Check permissions
ssh sysadmin@10.99.0.2 stat /var/log/kubernetes/audit.log

# Check disk space
ssh sysadmin@10.99.0.2 df -h /var/log/
```

### Etcd Encryption Issues
```bash
# Verify encryption config
kubectl get configmap -n kube-system | grep encryption

# Check etcd status (via WireGuard SSH)
ssh sysadmin@10.99.0.2 sudo systemctl status kubelet
```

### Certificate Expiration
```bash
# Check all certificates
kubernetes get certificates -A

# Renew if needed
cert-manager handles automatic renewal for Traefik certs
Manual renewal needed for internal PKI certs
```

## Additional Resources

- [Kubernetes Security Documentation](https://kubernetes.io/docs/concepts/security/)
- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)
- [etcd Security Best Practices](https://etcd.io/docs/v3.4.0/op-guide/security/)

