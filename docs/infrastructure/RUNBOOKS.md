# Operational Runbooks

Step-by-step procedures for common infrastructure operations.

## Emergency Access Procedures

### Using FRP Fallback Tunnel (If WireGuard Fails)

When WireGuard VPN is unavailable, use FRP (Fast Reverse Proxy) for emergency access.

**Prerequisites**: FRP token from terraform.tfvars

**Steps**:
```bash
# 1. SSH directly to bastion using FRP tunnel
ssh -i <your-key> -o ProxyUseFdpass=no \
    -L 6443:10.99.0.2:6443 \
    -p <frp-port> \
    frp@<bastion-public-ip>

# 2. In another terminal, use local kubectl
export KUBECONFIG=~/.kube/config
kubectl --kubeconfig=~/.kube/config get nodes

# 3. When done, close the tunnel (Ctrl+C in first terminal)
```

**Expected**: Access to Kubernetes API even if WireGuard is down

---

## Team Access Management

### Add a New Team Member to VPN

**Prerequisites**: Team member's public WireGuard key

**Steps**:
1. Get their public key:
   ```bash
   # Team member generates their key
   wg genkey | wg pubkey
   # Returns: ABCDEfgh...
   ```

2. Update terraform.tfvars:
   ```bash
   # Add to wireguard_peers list:
   wireguard_peers = [
     { name = "existing-person", public_key = "...", allowed_ips = ["10.99.0.5/32"] },
     { name = "new-person", public_key = "ABCDEfgh...", allowed_ips = ["10.99.0.6/32"] }
   ]
   ```

3. Apply changes:
   ```bash
   terraform plan
   terraform apply
   ```

4. Share updated WireGuard config with them:
   ```
   [Interface]
   Address = 10.99.0.6/32
   PrivateKey = <their-private-key>
   DNS = <bastion-public-ip>

   [Peer]
   PublicKey = <bastion-public-key>
   Endpoint = <bastion-public-ip>:51820
   AllowedIPs = 10.99.0.0/24
   PersistentKeepalive = 25
   ```

5. Verify connection:
   ```bash
   # Team member tests
   ping 10.99.0.1  # Should respond
   ```

### Remove Team Member Access

**Steps**:
1. Remove from wireguard_peers in terraform.tfvars
2. Apply: `terraform apply`
3. Their WireGuard config stops working (automatic)
4. SSH access also removed automatically

---

## Credential Rotation

### Rotate WireGuard Keys

When WireGuard keys need rotation for security reasons.

**Duration**: ~15 minutes downtime

**Steps**:
1. Generate new keys:
   ```bash
   wg genkey | tee debian-new-private.key | wg pubkey > debian-new-public.key
   wg genkey | tee bastion-new-private.key | wg pubkey > bastion-new-public.key
   ```

2. Update terraform.tfvars:
   ```bash
   debian_wireguard_private_key = "new-debian-private-key"
   bastion_wireguard_private_key = "new-bastion-private-key"
   bastion_wireguard_public_key = "new-bastion-public-key"
   ```

3. Update team member configs with new bastion public key

4. Apply changes:
   ```bash
   terraform plan
   terraform apply
   ```

5. Restart WireGuard on all clients:
   ```bash
   wg-quick down wg0
   wg-quick up wg0
   ```

6. Verify connectivity:
   ```bash
   ping 10.99.0.1  # Should work
   kubectl get nodes  # Should work
   ```

### Rotate SSH Keys

When SSH keys need rotation.

**Duration**: No downtime (brief SSH interruption)

**Steps**:
1. Generate new SSH key pairs for your team

2. Update terraform.tfvars:
   ```bash
   bastion_key_pair_name = "new-keypair-name"
   ssh_public_keys = [
     "ssh-rsa AAAA... person1@laptop",
     "ssh-rsa BBBB... person2@laptop"
   ]
   ```

3. Apply changes:
   ```bash
   terraform plan
   terraform apply
   ```

4. Test with new key:
   ```bash
   ssh -i ~/.ssh/new-key sysadmin@10.99.0.2
   ```

5. Verify old keys no longer work (remove from `.ssh/authorized_keys` if needed)

---

## Backup and Recovery

### Backup etcd State

Backup Kubernetes state before major changes.

**Steps**:
```bash
# SSH to Debian host through bastion
ssh -J sysadmin@10.99.0.1 sysadmin@10.99.0.2

# Create backup directory
mkdir -p /var/backups/etcd

# Take snapshot
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=127.0.0.1:2379 \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  snapshot save /var/backups/etcd/backup-$(date +%Y%m%d-%H%M%S).db

# Verify backup
sudo ls -lh /var/backups/etcd/
```

**Frequency**: Before major Kubernetes upgrades or configuration changes

### Restore from etcd Backup

If Kubernetes cluster is corrupted, restore from backup.

**Prerequisites**: Backup file from above procedure

**Duration**: 30-45 minutes with brief downtime

**Steps**:
```bash
# SSH to Debian host
ssh -J sysadmin@10.99.0.1 sysadmin@10.99.0.2

# Stop Kubernetes
sudo kubeadm reset -f

# Restore etcd (complex - requires etcd tools)
# It's easier to redeploy: terraform destroy && terraform apply

# Or restore specific backup:
sudo ETCDCTL_API=3 etcdctl \
  snapshot restore /var/backups/etcd/backup-FILE.db \
  --data-dir=/var/lib/etcd-restored

# Restart kubelet
sudo systemctl restart kubelet
```

**Note**: For production, use proper backup solutions (Velero, automated snapshots)

---

## Monitoring and Validation

### Daily Health Check

Quick validation that everything is working.

```bash
#!/bin/bash
set -e

echo "=== Cluster Health ==="
kubectl get nodes
echo "Status: $(kubectl get nodes -o jsonpath='{.items[0].status.conditions[-1].type}')"

echo "=== Pod Status ==="
kubectl get pods --all-namespaces
UNREADY=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running | wc -l)
if [ $UNREADY -lt 3 ]; then echo "✓ All pods healthy"; else echo "⚠ Some pods not running"; fi

echo "=== Storage ==="
kubectl get persistentvolumes

echo "=== VPN Status ==="
ping -c 1 10.99.0.1 && echo "✓ VPN connected" || echo "✗ VPN down"

echo "=== Bastion Status ==="
aws ec2 describe-instances --filters "Name=tag:Name,Values=bastion" \
  --query 'Reservations[0].Instances[0].[State.Name]' --output text

echo "=== Done ==="
```

### Pre-Deployment Checklist

Before applying infrastructure changes:

- [ ] Run daily health check (above)
- [ ] Backup etcd: `etcdctl snapshot save /tmp/backup.db`
- [ ] Review terraform plan: `terraform plan -out=tfplan`
- [ ] Test WireGuard connectivity: `ping 10.99.0.1`
- [ ] Verify SSH access: `ssh -J sysadmin@10.99.0.1 sysadmin@10.99.0.2 "echo OK"`
- [ ] Check disk space: `df -h`
- [ ] Review Kubernetes events: `kubectl get events -A`

---

## Common Deployments

### Deploy a Test Pod

Quick validation that cluster can run workloads.

```bash
# Create test deployment
kubectl create deployment test-nginx --image=nginx:latest

# Expose service
kubectl expose deployment test-nginx --port=80 --type=ClusterIP

# Port forward for testing
kubectl port-forward svc/test-nginx 8080:80

# Test (in another terminal)
curl localhost:8080

# Cleanup
kubectl delete deployment test-nginx
kubectl delete service test-nginx
```

### Scale Deployment

Increase pod replicas for load testing.

```bash
# Scale to 3 replicas
kubectl scale deployment <deployment-name> --replicas=3

# Watch status
kubectl rollout status deployment/<deployment-name>

# Monitor resources
kubectl top pods
```

### Check Logs

Debugging pod issues.

```bash
# Get pod logs
kubectl logs <pod-name>

# Stream logs
kubectl logs -f <pod-name>

# Get previous logs (if crashed)
kubectl logs <pod-name> --previous

# Get logs from all pods in deployment
kubectl logs -l app=<label> --all-containers=true
```

---

## Security Operations

### Review Access Logs

Check who accessed the cluster.

```bash
# SSH to Debian host
ssh -J sysadmin@10.99.0.1 sysadmin@10.99.0.2

# Check Kubernetes audit log
sudo tail -f /var/log/kubernetes/audit.log

# Check SSH auth logs
sudo grep "sshd" /var/log/auth.log | tail -20
```

### Verify Network Policies

Ensure pod-to-pod security is working.

```bash
# List all network policies
kubectl get networkpolicies --all-namespaces

# Describe specific policy
kubectl describe networkpolicy <policy-name> -n <namespace>

# Test connectivity (if you have test pods)
kubectl exec -it <pod1> -- ping <pod2-ip>
```

---

**Last Updated**: December 4, 2025
**Status**: Production
**Version**: 1.0
