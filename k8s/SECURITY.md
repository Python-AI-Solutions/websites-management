# Security Guide

## Overview

This infrastructure implements multiple layers of security to protect your Kubernetes cluster:

1. **Network Isolation:** WireGuard VPN for all cluster access
2. **Encryption at Rest:** Etcd encryption (AES-CBC 256-bit)
3. **API Audit Logging:** Comprehensive audit trail of all API operations
4. **SSH Hardening:** Key-based authentication with bastion jump host
5. **Emergency Access:** FRP reverse proxy for breakglass scenarios
6. **RBAC:** Kubernetes role-based access control

---

## Secret Management

### Critical: terraform.tfvars

**Never commit this file to version control.**

This file contains:
- WireGuard private keys
- SSH public keys
- FRP authentication tokens
- AWS resource IDs
- Network configuration

**Protect this file:**

```bash
# Set restrictive permissions
chmod 600 terraform.tfvars

# Add to .gitignore (already configured)
echo "terraform.tfvars" >> .gitignore

# Consider using:
# - Terraform Cloud/Enterprise for encrypted remote storage
# - HashiCorp Vault for secret management
# - AWS Secrets Manager for sensitive values
```

### Secrets in Kubernetes

All Kubernetes secrets are encrypted at rest:

```bash
# Encryption configuration in tmp-encryption-config.yaml
# AES-CBC algorithm with 256-bit keys
# Affects: secrets, configmaps in specified namespaces

# Check encryption status
kubectl get secrets -A
kubectl describe secret -n kube-system generic-secret
```

---

## Network Security

### WireGuard VPN

All traffic to the cluster goes through WireGuard encrypted tunnel:

```
┌─────────────────┐
│  Your Machine   │
│  (10.99.0.x)    │
└────────┬────────┘
         │ WireGuard UDP:51820
         ├─ Encrypted tunnel
         │
┌────────▼────────────┐
│  Bastion Host (AWS) │ ◄─ Public IP (exposed)
│  (10.99.0.1)        │
└────────┬────────────┘
         │ Private network
         │
┌────────▼─────────────┐
│  Debian/K8s Host     │
│  (192.168.1.123)     │
│  (10.99.0.2)         │
└──────────────────────┘
```

### Security Groups

**Bastion Security Group:**

```
Inbound:
  - SSH (22): Limited to bootstrap_ssh_cidrs
  - WireGuard UDP (51820): Open to 0.0.0.0/0
  - FRP (7000-7006): Limited to specific IPs

Outbound:
  - All traffic allowed
```

**Kubernetes Cluster:**
- Only accessible via WireGuard tunnel (10.99.0.0/24)
- API server: 192.168.1.123:6443
- kubelet: 10250
- etcd: 2379-2380

### Firewall Rules

**Debian Host iptables:**

```bash
# Allow traffic from WireGuard peers only
sudo iptables -L -n

# Rate limiting on SSH
sudo fail2ban-client status sshd

# Verify port restrictions
sudo netstat -tlnp | grep LISTEN
```

### SSH Hardening

**Bastion SSH Configuration:**

```bash
# Key-based auth only (password disabled)
PasswordAuthentication no

# Only specific users allowed
AllowUsers newuser

# Limit concurrent sessions
MaxSessions 5
MaxStartups 10:30:60

# Timeout idle connections
ClientAliveInterval 300
ClientAliveCountMax 2

# Restrict algorithms
KexAlgorithms curve25519-sha256,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr
```

---

## Encryption

### Data at Rest: Etcd

Kubernetes etcd is encrypted with AES-CBC-256:

```bash
# Check encryption configuration
kubectl -n kube-system exec -it etcd-master -- \
  curl -s --cert /etc/kubernetes/pki/etcd/server.crt \
  --key /etc/kubernetes/pki/etcd/server.key \
  https://127.0.0.1:2379/v3/status

# Verify secrets are encrypted
cat /var/lib/etcd/member/snap/db | strings | grep "your-secret"
# Should NOT show plaintext
```

**Configuration:**
```yaml
# tmp-encryption-config.yaml
resources:
  - secrets
  - configmaps
provider:
  aescbc:
    keys:
      - name: key1
        secret: <base64-encoded-32-byte-key>
```

### Data in Transit: TLS

**API Server (6443):**
- TLS 1.2+
- Certificate signed by cluster CA
- Client certificates for kubelet, proxy

**WireGuard:**
- UDP encrypted with ChaCha20-Poly1305
- Perfect forward secrecy
- DDoS resistant

**Certificates:**

```bash
# Check certificate expiration
kubectl get csr
kubectl certificate approve csr-xxx

# Verify API server cert
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates

# kubelet certs auto-rotate via CSR
```

### Volume Encryption (AWS)

**Root volume encrypted with KMS:**

```bash
# Check volume encryption
aws ec2 describe-volumes --volume-ids vol-xxx \
  | grep -i encrypted

# KMS Key ID
arn:aws:kms:us-east-1:ACCOUNT:key/UUID
```

---

## Kubernetes RBAC

### Default Roles

```bash
# Cluster roles
kubectl get clusterrole
kubectl describe clusterrole view

# Cluster role bindings
kubectl get clusterrolebinding
kubectl describe clusterrolebinding system:public-info-viewer

# Service accounts per namespace
kubectl get sa -A
```

### User/Service Account Access

```bash
# List authenticated users
kubectl config get-users

# Check RBAC permissions
kubectl auth can-i get pods --as=system:serviceaccount:default:my-sa
kubectl auth can-i list secrets --as=john-user

# Impersonate user for testing
kubectl get pods --as=john-user
```

### Pod Security

Pods run with restricted context:

```bash
# Check security context
kubectl get pod -o yaml | grep -A10 securityContext

# Example restrictions:
# - runAsNonRoot: true
# - readOnlyRootFilesystem: true
# - allowPrivilegeEscalation: false
# - capabilities.drop: ALL
```

---

## Audit Logging

### Kubernetes API Audit

**All sensitive operations are logged:**

```yaml
# Captured in tmp-audit-policy.yaml
RequestResponse level for:
  - secrets (all operations)
  - configmaps (create/patch/delete/update)
  - clusterroles, clusterrolebindings
  - service accounts
  - pods/exec, pods/portforward
  - deployments, daemonsets, statefulsets
```

### Accessing Audit Logs

**On Kubernetes master:**

```bash
# Audit log location
sudo tail -f /var/log/kubernetes/audit.log

# Parse JSON audit logs
sudo jq . /var/log/kubernetes/audit.log | grep '"verb":"delete"'

# Find secret access
sudo jq 'select(.objectRef.resource=="secrets")' /var/log/kubernetes/audit.log

# Find failed authentication
sudo jq 'select(.stage=="ResponseComplete" and .responseStatus.code>=400)' /var/log/kubernetes/audit.log

# Find user activity
sudo jq 'select(.user.username=="john")' /var/log/kubernetes/audit.log
```

### Log Rotation

Audit logs are rotated automatically:

```bash
# Configuration
MaxAge: 30 days
MaxBackup: 10 files
MaxSize: 100MB

# View rotated logs
sudo ls -la /var/log/kubernetes/audit-*.log
```

### Log Analysis

Example audit log entries:

```json
{
  "level": "RequestResponse",
  "auditID": "abc123",
  "stage": "ResponseComplete",
  "requestReceivedTimestamp": "2024-01-15T10:30:00.000Z",
  "stageTimestamp": "2024-01-15T10:30:01.000Z",
  "verb": "create",
  "objectRef": {
    "resource": "secrets",
    "namespace": "default",
    "name": "db-password"
  },
  "user": {
    "username": "john@example.com"
  },
  "sourceIPs": ["10.99.0.15"],
  "responseStatus": {
    "code": 201
  }
}
```

---

## Emergency Access (FRP)

### FRP Reverse Proxy

If WireGuard fails, FRP provides breakglass access:

```bash
# FRP client runs on Debian host
# Maintains persistent tunnel to FRP server

# Check FRP status
ps aux | grep frpc

# FRP logs
sudo journalctl -u frp -n 50
```

### FRP Architecture

```
┌──────────────────┐
│  FRP Server      │
│  (bastion)       │
└────────────────┬─┘
                 │ Persistent tunnel
                 │ (reverse proxy)
┌────────────────▼─┐
│  FRP Client      │
│  (debian/k8s)    │
└──────────────────┘
```

### Using FRP Emergency Access

```bash
# From anywhere, connect via FRP
ssh -p 2222 root@frp-server-address

# Or if SSH is on different port
ssh -p 7005 root@frp-server-address
```

---

## Regular Security Tasks

### Daily

- [ ] Monitor audit logs for unusual activity
- [ ] Check pod logs for errors/security issues
- [ ] Verify WireGuard peers are connected

### Weekly

- [ ] Review RBAC permissions
- [ ] Check certificate expiration dates
- [ ] Audit Kubernetes API access patterns
- [ ] Monitor resource usage (disk/memory/CPU)

### Monthly

- [ ] Rotate encryption keys (if using Vault)
- [ ] Update Kubernetes to latest patch version
- [ ] Review security group rules
- [ ] Perform network security assessment
- [ ] Archive and backup audit logs

### Quarterly

- [ ] Rotate WireGuard peer keys
- [ ] Rotate SSH keys for bastion
- [ ] Security audit of cluster configuration
- [ ] Test disaster recovery procedures
- [ ] Update security policies

### Annually

- [ ] Rotate KMS keys (AWS)
- [ ] Rotate service account credentials
- [ ] Full security assessment
- [ ] Update incident response procedures
- [ ] Compliance review

---

## Security Checklist

- [ ] terraform.tfvars not committed
- [ ] SSH keys properly secured (chmod 600)
- [ ] .gitignore configured for sensitive files
- [ ] WireGuard keys rotated (document dates)
- [ ] API audit logging enabled
- [ ] Etcd encryption enabled
- [ ] RBAC policies reviewed
- [ ] Network policies deployed
- [ ] Pod security standards enforced
- [ ] Certificate expiration monitored
- [ ] Backup/recovery tested
- [ ] Incident response plan documented
- [ ] Security updates applied regularly

---

## Common Security Issues

### Issue: SSH Key Exposed in Git

```bash
# Scan history for keys
git log -p | grep -i "private" | head

# Remove from history (careful!)
git filter-branch --tree-filter 'rm -f exposed-key' HEAD
```

### Issue: WireGuard Key Compromised

```bash
# Generate new keys
wg genkey | tee bastion-new.key | wg pubkey > bastion-new.pub

# Update terraform.tfvars
bastion_wireguard_private_key = "new-key"
bastion_wireguard_public_key = "new-pub-key"

# Apply changes
terraform apply

# Notify all clients to update their WireGuard configs
```

### Issue: Kubernetes Secret Leaked

```bash
# Rotate the secret
kubectl delete secret leaked-secret -n default
kubectl create secret generic new-secret --from-literal=password=new-value -n default

# Update applications to use new secret
kubectl rollout restart deployment -n default

# Verify secret rotation in audit logs
```

### Issue: Unauthorized API Access

```bash
# Check audit logs for unusual activity
grep "\"verb\":\"get\"" /var/log/kubernetes/audit.log | \
  grep "secrets" | tail -20

# Revoke compromised credentials
kubectl delete secret user-token -n default
kubectl delete user john@example.com

# Review RBAC bindings
kubectl get clusterrolebinding | grep john
```

---

## Security Resources

- **Kubernetes Security Best Practices:** https://kubernetes.io/docs/concepts/security/
- **NIST Cybersecurity Framework:** https://www.nist.gov/cyberframework
- **OWASP Top 10:** https://owasp.org/Top10/
- **CIS Kubernetes Benchmark:** https://www.cisecurity.org/benchmark/kubernetes
- **WireGuard Security:** https://www.wireguard.com/protocol/
- **HashiCorp Vault:** https://www.vaultproject.io/

---

## Questions or Concerns?

If you find security issues:

1. Document the issue in detail
2. Do not commit sensitive data
3. Consult with the team
4. Follow incident response procedures
5. Update this guide with lessons learned
