# FRP Emergency Access Runbook

**Status:** Emergency-only procedure (WireGuard VPN is primary access method)
**Last Updated:** 2025-11-14
**Audience:** Infrastructure team, authorized personnel only

---

## Overview

FRP (Fast Reverse Proxy) is a **legacy fallback mechanism** for accessing the bastion and Kubernetes cluster when the WireGuard VPN is unavailable. This runbook documents the emergency procedure.

**Normal Access:** Use WireGuard VPN (see [04-WIREGUARD_TECHNICAL_GUIDE.md](../additional-docs/04-WIREGUARD_TECHNICAL_GUIDE.md))
**Emergency Access:** Follow this procedure only when WireGuard is unavailable

---

## Prerequisites

- SSH key with bastion-admin access
- FRP client binary (`frpc`) installed locally
- Network access to FRP server (7005, 7006 TCP)
- Bastion host must have FRP server (`frps`) running

---

## Step 1: Verify WireGuard is Unavailable

```bash
# Check if WireGuard interface exists
ip link show wg0
# Expected: ❌ Device "wg0" does not exist

# Try pinging bastion over VPN
ping -c 2 10.99.0.1
# Expected: ❌ 100% packet loss (WireGuard not working)

# Try SSH to Debian host directly (will fail)
ssh sysadmin@10.99.0.20
# Expected: ❌ Network is unreachable
```

If any of these work, use WireGuard instead of this emergency procedure.

---

## Step 2: Enable FRP on Bastion (Admin Action)

**This must be done by someone with bastion-admin SSH access:**

```bash
# SSH to bastion
ssh bastion-admin

# Check FRP server status
sudo systemctl status frps
# Expected: ● frps.service - Loaded and active (running)

# If not running, start it
sudo systemctl start frps

# Verify FRP ports are listening
sudo ss -tlnp | grep frp
# Expected output:
#   LISTEN  0  128  0.0.0.0:7005  0.0.0.0:*  (FRP control port)
#   LISTEN  0  128  0.0.0.0:7006  0.0.0.0:*  (FRP SSH tunnel)
```

---

## Step 3: Enable FRP Bootstrap (Bastion Side)

If FRP server is not enabled in bootstrap script, manually enable it:

```bash
# SSH to bastion
ssh bastion-admin

# Locate the bootstrap script
ls -la /opt/wireguard/bootstrap.sh
# or
ls -la /root/wireguard-bootstrap.sh

# Re-run bootstrap with FRP enabled
# (Ensure lines 6-7 and 70-72 are uncommented in bootstrap)
sudo bash /path/to/wireguard-bootstrap.sh
```

---

## Step 4: Setup FRP Client (Local Machine)

```bash
# Install FRP client (if not already installed)
# macOS via Homebrew:
brew install frp

# Or download directly:
cd /tmp
wget https://github.com/fatedier/frp/releases/download/v0.52.0/frp_0.52.0_darwin_amd64.tar.gz
tar -xzf frp_0.52.0_darwin_amd64.tar.gz
cd frp_0.52.0_darwin_amd64

# Create FRP client config
cat > frpc.ini <<'EOF'
[common]
server_addr = <BASTION_PUBLIC_IP>
server_port = 7005
token = <FRP_TOKEN>  # Ask admin for token

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 7006
EOF

# Start FRP client
./frpc -c frpc.ini
```

---

## Step 5: SSH Through FRP Tunnel

Once FRP client is running locally:

```bash
# SSH to Debian host through FRP tunnel
# From local machine:
ssh -p 7006 sysadmin@localhost

# Or if FRP is on different machine:
ssh -p 7006 sysadmin@<BASTION_PUBLIC_IP>
```

---

## Step 6: Access Kubernetes Cluster

With SSH tunnel established:

```bash
# Export kubeconfig from the Debian host
ssh sysadmin@10.99.0.20 "cat ~/.kube/config" > kubeconfig.tmp

# Use it locally
export KUBECONFIG=$(pwd)/kubeconfig.tmp
kubectl get nodes

# ⚠️ Security: Delete the kubeconfig when done
rm kubeconfig.tmp
shred -u kubeconfig.tmp  # Secure deletion
```

---

## Troubleshooting

### FRP Connection Refused
```bash
# Verify bastion has FRP server running
ssh bastion-admin "sudo ss -tlnp | grep frp"

# Verify FRP ports are open in security group
aws ec2 describe-security-groups --query 'SecurityGroups[?GroupName==`bastion-sg`].IpPermissions[]'
```

### SSH Through Tunnel Fails
```bash
# Check FRP client is running
ps aux | grep frpc
# Expected: frpc process visible

# Check tunnel is active
curl -v telnet://localhost:7006
# Expected: Connected

# Check SSH key is loaded
ssh-add -L
```

### Kubernetes Commands Fail
```bash
# Verify kubeconfig is valid
kubectl config view

# Check cluster connectivity
kubectl get nodes
# If timeout: verify SSH tunnel is active
```

---

## When to Use This Procedure

✅ **USE THIS when:**
- WireGuard VPN is completely unavailable
- Emergency debugging needed
- Routine maintenance of WireGuard failed
- Authorized personnel requires fallback access

❌ **DO NOT USE for:**
- Regular operations (use WireGuard VPN instead)
- Development work (use WireGuard VPN)
- Teaching/training (use WireGuard VPN)
- Unplanned debugging (establish WireGuard first)

---

## Security Considerations

⚠️ **FRP tunnel is less secure than WireGuard:**
- FRP uses single authentication token (vs key-based in WireGuard)
- FRP traffic may be less encrypted than WireGuard (verify FRP TLS settings)
- FRP exposes ports publicly (vs WireGuard's encrypted tunnel)

✅ **Minimize risk:**
- Rotate FRP token after each emergency use
- Enable FRP only when needed, disable immediately after
- Log all FRP usage for audit
- Use network policies to restrict who can enable FRP
- Monitor FRP ports for unauthorized access attempts

---

## Cleanup After Emergency Access

```bash
# Stop FRP client (local)
# Kill the frpc process or Ctrl+C

# Disable FRP on bastion (admin action)
ssh bastion-admin
sudo systemctl stop frps
sudo systemctl disable frps

# Verify FRP ports are closed
sudo ss -tlnp | grep frp
# Expected: No FRP entries

# Restore normal WireGuard access
# (Fix WireGuard issue first, then re-activate tunnel)
```

---

## FRP Configuration Details

### FRP Server (Bastion Side)

```ini
# /etc/frp/frps.ini
[common]
bind_addr = 0.0.0.0
bind_port = 7005
log_file = /var/log/frps.log
log_level = info
authentication_method = token
token = <SECURE_TOKEN>
tls_mode = default

[plugin_frpc]
addr = 0.0.0.0
port = 7006
allow_users = *
```

### FRP Client (Local Side)

See Step 4 above for frpc.ini configuration.

---

## Contacting the Team

If FRP emergency access is needed:
1. **Immediate:** SSH to bastion (if possible): `ssh bastion-admin`
2. **If WireGuard down:** Follow this runbook
3. **For token:** Slack/email infrastructure team
4. **For issues:** Check logs in `/var/log/frps.log` (server) and `frpc.log` (client)

---

## Related Documentation

- [04-WIREGUARD_TECHNICAL_GUIDE.md](../additional-docs/04-WIREGUARD_TECHNICAL_GUIDE.md) - Primary VPN setup
- [02-DEPLOYMENT_QUICK_START.md](../additional-docs/02-DEPLOYMENT_QUICK_START.md) - Initial deployment
- [k8s/README.md](../k8s/README.md) - Kubernetes cluster access
- [aws/README.md](../aws/README.md) - Infrastructure overview

---

**Last Review:** 2025-11-14
**Next Review:** 2025-12-14
**Owner:** Infrastructure Team
