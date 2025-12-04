# Troubleshooting Guide

Quick solutions to common issues when deploying and managing the infrastructure.

## WireGuard VPN Issues

### Cannot connect to WireGuard endpoint

**Symptoms**: `wg-quick up` fails or connection times out

**Solution**:
1. Verify bastion is running:
   ```bash
   aws ec2 describe-instances --filters "Name=tag:Name,Values=bastion" --query 'Reservations[0].Instances[0].State.Name'
   ```

2. Check security group allows UDP 51820:
   ```bash
   aws ec2 describe-security-groups --filters "Name=group-name,Values=wireguard-sg"
   ```

3. Verify your public key is in `wireguard_peers` in terraform.tfvars

4. Restart WireGuard:
   ```bash
   wg-quick down wg0
   wg-quick up wg0
   ```

### DNS not working through VPN

**Symptoms**: `ping 10.99.0.1` works but `nslookup example.com` fails

**Solution**:
1. Check DNS is configured in WireGuard config:
   ```bash
   cat /etc/wireguard/wg0.conf | grep -i dns
   ```

2. Should show: `DNS = <bastion-ip>`

3. On macOS, restart DNS resolution:
   ```bash
   sudo dscacheutil -flushcache
   ```

---

## Kubernetes Access Issues

### kubectl: Unable to connect to server

**Symptoms**: `kubectl get pods` returns connection error

**Solution**:
1. Verify kubeconfig exists:
   ```bash
   ls -la ~/.kube/config
   ```

2. Check API server is accessible through WireGuard:
   ```bash
   curl -k https://10.99.0.2:6443/api/v1/nodes 2>/dev/null | head -20
   ```

3. Verify kubeconfig points to correct server:
   ```bash
   kubectl config view | grep server
   # Should show: server: https://10.99.0.2:6443
   ```

### Permission denied when running kubectl

**Symptoms**: `error: You must be logged in to the server`

**Solution**:
1. Ensure kubeconfig has correct permissions:
   ```bash
   chmod 600 ~/.kube/config
   ```

2. Verify certificate is not expired:
   ```bash
   kubectl config view | grep certificate-data | head -1 | cut -d' ' -f6 | base64 -d | openssl x509 -noout -dates
   ```

3. If expired, regenerate from bastion via kubeadm

---

## Terraform Deployment Issues

### kubeadm bootstrap timeout

**Symptoms**: `terraform apply` hangs at "Waiting for kubeadm join..."

**Solution**:
1. This is normal for first-time deployments (can take 5-10 minutes)

2. If it times out after 15+ minutes:
   ```bash
   # SSH to Debian host through bastion
   ssh -J sysadmin@10.99.0.1 sysadmin@10.99.0.2

   # Check kubeadm status
   sudo kubeadm init status

   # Check systemd logs
   sudo journalctl -u kubelet -n 50
   ```

3. Common causes:
   - Network connectivity issues
   - DNS resolution problems
   - Insufficient disk space

### terraform apply fails with state lock

**Symptoms**: `Error acquiring the lock: ...`

**Solution**:
1. Check if another deploy is running:
   ```bash
   terraform show
   ```

2. If no other process is running, force unlock:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

3. Re-run the apply:
   ```bash
   terraform apply
   ```

### Module version mismatch

**Symptoms**: `Error: module source does not match ...`

**Solution**:
1. Reinitialize Terraform:
   ```bash
   rm -rf .terraform/
   terraform init
   ```

2. Verify providers are correct:
   ```bash
   terraform version
   ```

---

## Network and Connectivity

### SSH timeout when connecting through bastion

**Symptoms**: `ssh: connect to host 10.99.0.2 port 22: Connection timed out`

**Solution**:
1. Verify VPN is connected:
   ```bash
   ping 10.99.0.1  # Should work
   ```

2. Check bastion security group allows SSH from VPN:
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id> --query 'SecurityGroups[0].IpPermissions'
   ```

3. Verify SSH key is loaded:
   ```bash
   ssh-add -L | grep -i rsa
   ```

### Pod-to-pod communication failing

**Symptoms**: `ping` between pods fails

**Solution**:
1. Verify Cilium CNI is running:
   ```bash
   kubectl get pods -n kube-system | grep cilium
   # Should show cilium-xxxx pods as Running
   ```

2. Check NetworkPolicy if defined:
   ```bash
   kubectl get networkpolicies --all-namespaces
   ```

3. Inspect pod network:
   ```bash
   kubectl exec -it <pod-name> -- ip route
   ```

---

## DNS Issues

### DNS resolution slow or intermittent

**Symptoms**: Occasional `Failed to resolve` errors

**Solution**:
1. Check CoreDNS is running:
   ```bash
   kubectl get pods -n kube-system | grep coredns
   ```

2. Verify CoreDNS ConfigMap:
   ```bash
   kubectl get configmap coredns -n kube-system -o yaml
   ```

3. Check system DNS on Debian host:
   ```bash
   systemctl status systemd-resolved
   cat /etc/resolv.conf
   ```

### External DNS not resolving

**Symptoms**: `nslookup external-domain.com` fails in pods

**Solution**:
1. Check CoreDNS upstream DNS:
   ```bash
   kubectl get configmap coredns -n kube-system -o yaml | grep forward
   ```

2. Verify firewall allows DNS (UDP 53):
   ```bash
   sudo iptables -L | grep 53
   ```

3. Test from host:
   ```bash
   nslookup google.com 8.8.8.8
   ```

---

## Quick Diagnostics

Run this script to gather diagnostic information:

```bash
#!/bin/bash
echo "=== VPN Status ==="
wg show

echo "=== Kubernetes Status ==="
kubectl cluster-info
kubectl get nodes

echo "=== Bastion Status ==="
aws ec2 describe-instances --filters "Name=tag:Name,Values=bastion" \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress]'

echo "=== Terraform State ==="
terraform show | head -50

echo "=== System Logs ==="
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

---

## Still Stuck?

1. Check Kubernetes events: `kubectl describe pod <name>`
2. Review system logs: `sudo journalctl -u kubelet -n 100`
3. Check WireGuard logs: `wg show`
4. Review Terraform logs: `TF_LOG=DEBUG terraform apply`

---

**Last Updated**: December 4, 2025
**Status**: Production
