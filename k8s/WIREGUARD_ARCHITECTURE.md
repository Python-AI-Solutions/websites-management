# WireGuard Architecture & Access Flow

## Overview
This infrastructure uses WireGuard VPN for secure, encrypted access to cloud resources from your local machine. All traffic flows through an encrypted tunnel to Bastion (AWS EC2), which routes to Debian (on-premises).

```
Your Mac (10.99.0.10)
    ↓
WireGuard Tunnel (UDP:51820)
    ↓
Bastion/Jump Host (10.99.0.1) - AWS EC2
    ↓
Debian Host (10.99.0.2) - Kubernetes Control Plane
```

---

## Components

### 1. **WireGuard VPN**
- **Type**: Peer-to-peer encrypted tunnel
- **Protocol**: UDP on port 51820
- **Subnet**: 10.99.0.0/24 (private WireGuard network)
- **Your Mac IP**: 10.99.0.10/32
- **Bastion IP**: 10.99.0.1/24
- **Debian IP**: 10.99.0.2/32

### 2. **Bastion Host (AWS EC2)**
- **Public IP**: 3.82.253.109 (external access point)
- **WireGuard IP**: 10.99.0.1/24 (VPN server)
- **Role**: WireGuard server, jump host, FRP reverse proxy server
- **SSH User**: `newuser` (uses John's keys from terraform.tfvars)
- **Admin User**: `admin` (for administrative tasks)

### 3. **Debian Host (On-Premises)**
- **WireGuard IP**: 10.99.0.2/32 (only accessible via VPN)
- **SSH User**: `sysadmin` (passwordless sudo)
- **Role**: Kubernetes control plane
- **SSH Restrictions**: Only accepts SSH from 10.99.0.0/24 (WireGuard subnet) via iptables

### 4. **Kubernetes Cluster**
- **Control Plane Endpoint**: 192.168.1.123:6443 (on-premises internal network)
- **Pod Network**: 10.244.0.0/16 (Cilium)
- **Service Network**: 10.96.0.0/12
- **Location**: Debian host (single-node cluster)

---

## SSH Access Flow

### Connect to Debian (Primary Access)
```bash
# Direct via WireGuard tunnel
ssh sysadmin@10.99.0.2

# What happens:
# 1. Your Mac's WireGuard interface (utun6) connects to Bastion's WireGuard
# 2. Traffic is encrypted and routed through VPN
# 3. SSH reaches Debian on 10.99.0.2 port 22
# 4. Authentication via SSH agent (configured in ~/.ssh/config)
```

### Connect to Bastion (via WireGuard VPN)
```bash
# Connect through WireGuard VPN - uses sysadmin user
ssh sysadmin@10.99.0.1

# This is the same user/key pair used for Debian access
# The WireGuard IP 10.99.0.1 routes through the encrypted VPN tunnel
```

---

## Terraform Configuration (terraform.tfvars)

The `terraform.tfvars` file in `/k8s/` defines:

```hcl
# WireGuard Private Keys (Keep Secret!)
debian_wireguard_private_key  = "4Cjlvtm62BQufiTxlTSsv61DtkVRMVjw03nsuxtDBG0="
bastion_wireguard_private_key = "yG0xWHFCfVRotwhJ+VQHD52ow4M6I1iCLeSvE6bYtVc="
bastion_wireguard_public_key  = "39oLcmw2XRX57PguWfsqlZmURajuRJQiUUj+mvqIWhU="

# SSH Keys (for Bastion access)
jump_host_jump_user           = "newuser"
jump_host_jump_user_public_key = "ssh-ed25519 AAAAC3N..." # John's key
jump_host_admin_authorized_key = "ssh-ed25519 AAAAC3N..." # John's admin key

# AWS Security Group Whitelist (for Terraform bootstrap)
jump_host_bootstrap_ssh_cidrs = ["51.37.143.220/32", "223.190.80.154/32"]

# WireGuard Peers Configuration
wireguard_peers = [
  { name = "debian-host", public_key = "LpSeYGB1WDHHLr...", allowed_ips = ["10.99.0.2/32"], persistent_keepalive = 25 },
  { name = "john-laptop", public_key = "SK5gYFUBINcDwt...", allowed_ips = ["10.99.0.15/32"], persistent_keepalive = 25 },
  { name = "sumit-laptop", public_key = "9Tqh+qTAexAeJ6...", allowed_ips = ["10.99.0.10/32"], persistent_keepalive = 25 }
]

# Kubernetes Configuration
control_plane_endpoint = "192.168.1.123:6443"
enable_frp_emergency = true
deploy_debian_host = true
deploy_kubernetes_cluster = true
```

**Key Points:**
- **Private keys**: Used to establish WireGuard tunnel encryption
- **Public keys**: Shared with peers to identify and validate connections
- **allowed_ips**: Each peer can only route its specific IP (e.g., your Mac only routes 10.99.0.10)
- **persistent_keepalive**: Keeps tunnel active by sending periodic pings (25 seconds)
- **bootstrap_ssh_cidrs**: Temporary AWS security group rule for initial Terraform provisioning

---

## Prerequisites & Requirements

Before accessing Debian through WireGuard and SSH, ensure you have:

### 1. **WireGuard Installation**
```bash
# macOS - Install WireGuard CLI tools
brew install wireguard-tools

# Verify installation
wg --version
wg-quick --version
```

### 2. **SSH Key Setup**
You need the SSH private key for `sysadmin` user on Debian:
```bash
# Location: ~/.ssh/johnlee_k8s
# This key should be:
# - Readable by your user: chmod 600 ~/.ssh/johnlee_k8s
# - Added to SSH agent: ssh-add ~/.ssh/johnlee_k8s
# - Registered in ~/.ssh/config for automatic use

# Verify key permissions
ls -la ~/.ssh/johnlee_k8s
# Should show: -rw------- (600)
```

### 3. **SSH Config File (~/.ssh/config)**
Add or verify this entry:
```bash
Host debian
    HostName 10.99.0.2
    User sysadmin
    IdentityFile ~/.ssh/johnlee_k8s
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts
```

### 4. **WireGuard Configuration File**
Location: `~/.config/wireguard/sumit.conf`
- Must exist with correct permissions: `600`
- Contains your private key for VPN access
- Peer configuration pointing to Bastion at `3.82.253.109:51820`

---

## Your Mac Setup

### Activate WireGuard
```bash
# Start the VPN tunnel
sudo wg-quick up ~/.config/wireguard/sumit.conf

# Verify tunnel is active
ifconfig utun6          # Should show inet 10.99.0.10

# Test connectivity
ping 10.99.0.1          # Bastion
ping 10.99.0.2          # Debian

# Stop when done
sudo wg-quick down ~/.config/wireguard/sumit.conf
```

### WireGuard Config File (~/.config/wireguard/sumit.conf)
```ini
[Interface]
PrivateKey = EIrWLuWPj+tuw/Pq1oTfoCbr2pKBJ9GC2SYmAKB3c0I=  # Your private key
Address = 10.99.0.10/32                                      # Your VPN IP
DNS = 1.1.1.1

[Peer]
PublicKey = 39oLcmw2XRX57PguWfsqlZmURajuRJQiUUj+mvqIWhU=    # Bastion's public key
Endpoint = 3.82.253.109:51820                                # Bastion's external IP
AllowedIPs = 10.99.0.0/24                                    # Route entire VPN subnet
PersistentKeepalive = 25
```

---

## How to Access Debian via SSH

### Complete Access Workflow

#### Step 1: Ensure All Prerequisites Are Met
```bash
# Check WireGuard is installed
wg-quick --version

# Check SSH key exists and has correct permissions
ls -la ~/.ssh/johnlee_k8s
# Output should be: -rw------- 1 user group ... johnlee_k8s

# If permissions are wrong, fix them:
chmod 600 ~/.ssh/johnlee_k8s
```

#### Step 2: Add SSH Key to Agent (if not already added)
```bash
# Add the private key to SSH agent for this session
ssh-add ~/.ssh/johnlee_k8s

# Verify key is loaded in agent
ssh-add -l | grep johnlee_k8s
# Should show the key fingerprint
```

#### Step 3: Start WireGuard Tunnel
```bash
# Activate the VPN tunnel
sudo wg-quick up ~/.config/wireguard/sumit.conf

# Verify tunnel is running
ifconfig utun6
# Should show: inet 10.99.0.10 netmask 0xffffffff

# Check WireGuard status
sudo wg show
# Should show Bastion peer with handshake info
```

#### Step 4: Test Connectivity
```bash
# Ping Bastion (10.99.0.1)
ping -c 2 10.99.0.1
# Expected: replies from 10.99.0.1

# Ping Debian (10.99.0.2)
ping -c 2 10.99.0.2
# Expected: replies from 10.99.0.2
```

#### Step 5: Connect to Debian via SSH
```bash
# Using SSH config (recommended - simplest)
ssh debian

# Or direct connection
ssh sysadmin@10.99.0.2

# With verbose output if needed
ssh -vv sysadmin@10.99.0.2
```

### What You Should See
```
sysadmin@10.99.0.2's password:  # Should NOT appear (key-based auth)

# Successful connection shows:
Last login: [timestamp] from 10.99.0.10
sysadmin@debian:~$
```

### Where the SSH Key Came From
The `johnlee_k8s` SSH key pair:
- **Generated**: During initial infrastructure setup (by John Lee)
- **Public key**: Added to `/home/sysadmin/.ssh/authorized_keys` on Debian host
- **Private key**: Located at `~/.ssh/johnlee_k8s` on your Mac
- **Usage**: Terraform and manual SSH access to Debian control plane
- **Permissions**: Must be `600` (read/write owner only)

### How SSH Access is Configured on Debian
1. **User account**: `sysadmin` with passwordless sudo privileges
2. **SSH restrictions**:
   - Only accepts connections from WireGuard subnet (`10.99.0.0/24`)
   - Enforced by iptables firewall rules
   - Cannot SSH directly from public internet
3. **Key-based authentication**: Only public key auth enabled (no passwords)
4. **SSH config location**: `/etc/ssh/sshd_config`

---

## Network Security

### SSH Access Restrictions on Debian
```bash
# Debian only accepts SSH from WireGuard subnet (via iptables)
sudo iptables -L INPUT -n | grep dpt:22

# Output: Only allows from 10.99.0.0/24
# This means: SSH only works if your traffic comes through WireGuard
```

### Firewall Rules
- **TCP 22 (SSH)**: Only from 10.99.0.0/24 (WireGuard)
- **UDP 51820 (WireGuard)**: Open to internet
- **TCP 6443 (Kubernetes API)**: Only from 10.99.0.0/24
- **TCP 80/443 (HTTP/HTTPS)**: Open for Traefik ingress

---

## Kubernetes Access

Once `tofu apply` completes:

```bash
# Set kubeconfig location
export KUBECONFIG=/Users/anybody/Desktop/Work/PiHex\ Labs/Python\ AI\ Solutions/websites-management/k8s/kubeconfig

# Access Kubernetes cluster (requires Debian SSH access)
kubectl get nodes
kubectl get pods --all-namespaces
```

**Note**: Kubernetes API server at 192.168.1.123:6443 is only reachable from Debian host. Your Mac can't reach it directly (it's on-premises), but you can use `kubectl` through SSH tunneling if needed.

---

## Troubleshooting

### Common Issues and Solutions

#### 1. **`ping 10.99.0.1` or `ping 10.99.0.2` fails**

**Symptoms**: Cannot reach Bastion or Debian through VPN

**Diagnostic Steps**:
```bash
# Step 1: Check WireGuard is running
ifconfig utun6
# If not found, WireGuard is NOT active

# Step 2: Check WireGuard configuration file exists
ls -la ~/.config/wireguard/sumit.conf
# Should show: -rw------- (600 permissions)

# Step 3: Check for errors when starting WireGuard
sudo wg-quick up ~/.config/wireguard/sumit.conf

# Step 4: View WireGuard interface status
sudo wg show
# Look for:
# - interface: wg0 or utun6
# - peer with Bastion public key
# - latest handshake timestamp (recent)

# Step 5: Check if Bastion is reachable
curl -I https://3.82.253.109:51820 2>&1 | head -5
```

**Solutions**:
1. Start WireGuard: `sudo wg-quick up ~/.config/wireguard/sumit.conf`
2. Verify config file syntax: `cat ~/.config/wireguard/sumit.conf`
3. Check permissions: `chmod 600 ~/.config/wireguard/sumit.conf`
4. Check network connectivity to Bastion's public IP (3.82.253.109)
5. Restart WireGuard: `sudo wg-quick down ~/.config/wireguard/sumit.conf && sudo wg-quick up ~/.config/wireguard/sumit.conf`

---

#### 2. **`ssh sysadmin@10.99.0.2` times out or Connection Refused**

**Symptoms**: WireGuard works (ping succeeds) but SSH fails

**Diagnostic Steps**:
```bash
# Step 1: Verify WireGuard tunnel is active
ifconfig utun6
# Must show: inet 10.99.0.10

# Step 2: Verify ping to Debian works
ping -c 2 10.99.0.2

# Step 3: Check if SSH key is in agent
ssh-add -l | grep johnlee_k8s
# If not listed, key is not loaded

# Step 4: Try SSH with verbose output
ssh -vv sysadmin@10.99.0.2
# Look for:
# - "Trying 10.99.0.2 port 22..."
# - "Connected to 10.99.0.2"
# - Key authentication attempts
# - Error messages at end

# Step 5: Check SSH config
cat ~/.ssh/config | grep -A 5 "Host debian"

# Step 6: Test with ssh-keyscan
ssh-keyscan -p 22 10.99.0.2 2>&1
# Should return Debian's SSH public key
```

**Solutions**:
1. Add SSH key to agent: `ssh-add ~/.ssh/johnlee_k8s`
2. Fix SSH key permissions: `chmod 600 ~/.ssh/johnlee_k8s`
3. Verify SSH config file exists and is correct: `~/.ssh/config`
4. Check Debian's SSH restrictions (see "SSH Access Restrictions on Debian" section)
5. Try direct connection: `ssh -i ~/.ssh/johnlee_k8s sysadmin@10.99.0.2`

---

#### 3. **SSH Key Denied: "Permission denied (publickey)"**

**Symptoms**: Can ping Debian but SSH fails with permission error

**Diagnostic Steps**:
```bash
# Step 1: Check key is loaded in agent
ssh-add -l

# Step 2: Check key file exists and permissions are correct
ls -la ~/.ssh/johnlee_k8s
# Must be exactly: -rw------- (600)

# Step 3: Test key directly without agent
ssh -i ~/.ssh/johnlee_k8s -o IdentitiesOnly=yes sysadmin@10.99.0.2

# Step 4: Check public key on Debian (if you have access)
ssh sysadmin@10.99.0.2 'cat ~/.ssh/authorized_keys'
# Should include John's public key
```

**Solutions**:
1. Load key in SSH agent: `ssh-add ~/.ssh/johnlee_k8s`
2. Fix permissions: `chmod 600 ~/.ssh/johnlee_k8s`
3. Verify key is in authorized_keys on Debian
4. Try different key if available: `ssh-add -l` to see all loaded keys
5. Disable SSH config temporarily: `ssh -i ~/.ssh/johnlee_k8s -F /dev/null sysadmin@10.99.0.2`

---

#### 4. **`ssh sysadmin@10.99.0.1` (Bastion) Connection Refused**

**Symptoms**: Cannot SSH to Bastion through WireGuard IP

**Important**: This is EXPECTED behavior. Bastion's SSH daemon does NOT listen on the WireGuard interface (10.99.0.1).

**Solutions**:
- **Option 1 (Recommended)**: Use Terraform's SSH jump host through Bastion's public IP with private key auth
- **Option 2**: Connect directly to Debian (10.99.0.2) which IS accessible via WireGuard
- **Option 3**: SSH to Bastion's public IP directly if you need admin access:
  ```bash
  ssh -i /path/to/john/aws/key admin@3.82.253.109
  ```

---

#### 5. **SSH Key Not Found: "No such file or directory"**

**Symptoms**: Error like `~/.ssh/johnlee_k8s: No such file or directory`

**Diagnostic Steps**:
```bash
# Check if SSH key exists
ls -la ~/.ssh/johnlee_k8s

# List all SSH keys available
ls -la ~/.ssh/

# Check SSH agent has any keys
ssh-add -l
```

**Solutions**:
1. Verify key filename is correct: `johnlee_k8s` (not `johnlee.k8s` or other variants)
2. Create SSH directory if missing: `mkdir -p ~/.ssh && chmod 700 ~/.ssh`
3. Obtain the private key from John Lee or infrastructure team
4. Place it at: `~/.ssh/johnlee_k8s`
5. Set correct permissions: `chmod 600 ~/.ssh/johnlee_k8s`

---

#### 6. **WireGuard Connection Keeps Dropping**

**Symptoms**: Ping works for a while, then times out; need to restart WireGuard frequently

**Diagnostic Steps**:
```bash
# Check WireGuard handshake status
sudo wg show
# Look for "latest handshake:" - should be recent (seconds ago)

# Check if Bastion reachable on internet
ping 3.82.253.109

# Monitor WireGuard in real-time
watch -n 1 'sudo wg show'

# Check system logs for WireGuard issues
log stream --predicate 'process == "wireguard-go"' --level debug
```

**Solutions**:
1. Check internet connectivity to Bastion (3.82.253.109)
2. Restart WireGuard: `sudo wg-quick down ~/.config/wireguard/sumit.conf && sudo wg-quick up ~/.config/wireguard/sumit.conf`
3. Increase persistent keepalive in config: `PersistentKeepalive = 30` (or higher)
4. Check if firewall is blocking UDP 51820 to Bastion
5. Ensure WireGuard config has correct public key for Bastion

---

#### 7. **Terraform Apply Fails: "ssh: unable to authenticate"**

**Symptoms**: `tofu apply` fails during SSH connection to Debian for kubeadm provisioning

**Diagnostic Steps**:
```bash
# Check terraform.tfvars configuration
cat k8s/terraform.tfvars | grep -E "(bastion_ssh_user|bastion_wireguard)"

# Manually test SSH jump host
ssh -o ProxyCommand='ssh -i ~/.ssh/johnlee_k8s sysadmin@10.99.0.1 nc 10.99.0.2 22' sysadmin@10.99.0.2

# Check SSH agent has Terraform key
ssh-add -l | grep johnlee
```

**Solutions**:
1. **Critical**: Set `bastion_ssh_user = "sysadmin"` in terraform.tfvars (not "admin")
2. Ensure SSH key is in agent: `ssh-add ~/.ssh/johnlee_k8s`
3. Verify WireGuard is running before `tofu apply`
4. Check terraform.tfvars has correct key paths
5. Run `tofu validate` before `tofu apply`

---

#### 8. **Kubernetes API Server Unreachable (192.168.1.123:6443)**

**Symptoms**: `kubectl get nodes` fails; "unable to connect to API server"

**Expected Behavior**: This is EXPECTED - Kubernetes API is on-premises and only reachable from Debian host directly

**Solutions**:
1. Use kubeconfig file generated on Debian: `export KUBECONFIG=path/to/kubeconfig`
2. Copy kubeconfig from Debian to your Mac via SSH
3. Use kubectl through SSH tunneling if needed
4. Remember: API is at 192.168.1.123 (on-premises), not accessible from public internet

---

#### 9. **Quick Diagnostic Checklist (if access is not working)**

Run these commands in order to isolate the issue:

```bash
# 1. Check WireGuard installation
echo "=== WireGuard Installation ===" && wg-quick --version

# 2. Check WireGuard is running
echo "=== WireGuard Status ===" && ifconfig utun6 || echo "NOT RUNNING"

# 3. Check ping to VPN
echo "=== Ping Tests ===" && ping -c 1 10.99.0.1 && ping -c 1 10.99.0.2

# 4. Check SSH key
echo "=== SSH Key ===" && ls -la ~/.ssh/johnlee_k8s

# 5. Check SSH agent
echo "=== SSH Agent ===" && ssh-add -l | grep johnlee || echo "Key not loaded"

# 6. Check SSH config
echo "=== SSH Config ===" && cat ~/.ssh/config | grep -A 5 "Host debian" || echo "Config missing"

# 7. Test SSH with verbose
echo "=== SSH Test ===" && ssh -vv sysadmin@10.99.0.2 -o ConnectTimeout=5 echo "Connected" || echo "SSH FAILED"
```

This will quickly identify which component is failing.

---

## Current Setup Status & Verification (Tested 2025-12-03)

### Verified Working Components ✅

| Component | Status | Details | Last Verified |
|-----------|--------|---------|---|
| **WireGuard Installation** | ✅ Installed | `wg-quick` available, version: wireguard-tools | 2025-12-03 |
| **WireGuard Tunnel (utun6)** | ✅ Running | Interface active, IP: 10.99.0.10/32 | 2025-12-03 |
| **Bastion Connectivity** | ✅ Reachable | Ping 10.99.0.1: ~280ms, stable | 2025-12-03 |
| **Debian Connectivity** | ✅ Reachable | Ping 10.99.0.2: ~365ms, stable | 2025-12-03 |
| **SSH Key (johnlee_k8s)** | ✅ Available | Located: `~/.ssh/johnlee_k8s`, permissions: 600 | 2025-12-03 |
| **SSH Key in Agent** | ✅ Loaded | Fingerprint: Sumit Jha john-k8s 2025-11-04 | 2025-12-03 |
| **SSH to Debian** | ✅ Working | Connected as: `sysadmin@10.99.0.2` | 2025-12-03 |
| **Debian Hostname** | ✅ Verified | Hostname: `debian` | 2025-12-03 |
| **Debian User** | ✅ Verified | User: `sysadmin` (no password required) | 2025-12-03 |
| **Passwordless Sudo** | ✅ Configured | `sysadmin may run (ALL) NOPASSWD: ALL` | 2025-12-03 |
| **SSH Firewall Rules** | ✅ Correct | Rule: `ACCEPT tcp 10.99.0.0/24 tcp dpt:22 (SSH WireGuard only)` | 2025-12-03 |
| **WireGuard Subnet** | ✅ Correct | Subnet: 10.99.0.0/24, Your IP: 10.99.0.10 | 2025-12-03 |
| **Bastion Public IP** | ✅ Reachable | IP: 3.82.253.109:51820 (UDP) | 2025-12-03 |

### Known Issues & Limitations ⚠️

| Issue | Status | Reason | Workaround |
|-------|--------|--------|-----------|
| **Kubernetes API (192.168.1.123:6443)** | ⚠️ Unreachable | API on-premises only, not accessible via WireGuard | Use kubeconfig from Debian host directly |
| **Bastion SSH (10.99.0.1:22)** | ⚠️ No SSH daemon | Bastion doesn't listen on WireGuard IP | Use Bastion public IP (3.82.253.109) or connect to Debian |

---

## Connection Recovery Procedures

### If Debian SSH Access Stops Working

Follow this step-by-step recovery procedure:

#### **Step 1: Quick Status Check (2 minutes)**
```bash
# Test all components quickly
echo "=== WireGuard Status ===" && ifconfig utun6 || echo "FAILED"
echo "=== Ping Bastion ===" && ping -c 1 -W 2 10.99.0.1 || echo "FAILED"
echo "=== Ping Debian ===" && ping -c 1 -W 2 10.99.0.2 || echo "FAILED"
echo "=== SSH Key Loaded ===" && ssh-add -l | grep johnlee || echo "FAILED"
echo "=== SSH Test ===" && ssh -o ConnectTimeout=3 sysadmin@10.99.0.2 "echo OK" || echo "FAILED"
```

#### **Step 2: WireGuard Not Running? Restart It**
```bash
# If ifconfig utun6 shows "does not exist", restart WireGuard
sudo wg-quick down ~/.config/wireguard/sumit.conf 2>/dev/null || true
sudo wg-quick up ~/.config/wireguard/sumit.conf

# Verify it's running
ifconfig utun6
# Should show: inet 10.99.0.10

# Check WireGuard details
sudo wg show
# Should show:
# - interface: wg0 or utun6
# - peer: Bastion's public key
# - latest handshake: (should be recent)
```

#### **Step 3: Ping Not Working? Check Bastion**
```bash
# If both ping 10.99.0.1 and 10.99.0.2 fail after WireGuard is running:

# Check if Bastion's public IP is reachable (internet connectivity)
ping 3.82.253.109
# If this fails: You don't have internet or Bastion is down

# Check WireGuard is using correct config
cat ~/.config/wireguard/sumit.conf | grep -E "(PublicKey|Endpoint)"

# Check WireGuard handshake is recent
sudo wg show | grep "latest handshake"
# If it says "0 seconds ago": Connection is active
# If it says "minutes ago": No recent handshake, restart WireGuard
```

#### **Step 4: SSH Key Not in Agent? Reload It**
```bash
# If "ssh-add -l | grep johnlee" returns nothing:

# Add key to agent
ssh-add ~/.ssh/johnlee_k8s
# You'll be prompted for passphrase

# Verify it's loaded
ssh-add -l | grep johnlee
# Should show fingerprint: "Sumit Jha john-k8s 2025-11-04"

# Check key file permissions
ls -la ~/.ssh/johnlee_k8s
# Must show: -rw------- (exactly 600 permissions)
# If not: chmod 600 ~/.ssh/johnlee_k8s
```

#### **Step 5: SSH Timeout/Connection Refused? Debug Connection**
```bash
# Try SSH with verbose output to see exactly where it fails
ssh -vvv sysadmin@10.99.0.2

# Look for these messages:
# "Trying 10.99.0.2 port 22..." - Connection attempt
# "Connected to 10.99.0.2" - Network connection working
# "Authenticated" - SSH key accepted
# "Connection refused" - Debian not listening on SSH

# If you get "No route to host":
# - WireGuard is not running (check Step 2)
# - Bastion is not reachable (check Step 3)

# If you get "Connection refused":
# - SSH daemon on Debian is down
# - Check: ssh sysadmin@10.99.0.2 "sudo systemctl status ssh"
```

#### **Step 6: SSH Key Permission Denied? Fix Key**
```bash
# If "Permission denied (publickey)" appears:

# Check key permissions
ls -la ~/.ssh/johnlee_k8s
# Must be exactly: -rw------- (600)

# If wrong, fix it:
chmod 600 ~/.ssh/johnlee_k8s

# Verify the key works
ssh -i ~/.ssh/johnlee_k8s -o IdentitiesOnly=yes sysadmin@10.99.0.2

# If still fails, key might be wrong. Check:
ssh sysadmin@10.99.0.2 "cat ~/.ssh/authorized_keys"
# Should contain John's public key
```

#### **Step 7: Full Connection Restoration Sequence**
```bash
# If Step 1-6 didn't work, run this complete restoration:

# 1. Stop WireGuard
echo "Stopping WireGuard..."
sudo wg-quick down ~/.config/wireguard/sumit.conf 2>/dev/null || true

# 2. Wait for interface to disappear
sleep 2
ifconfig utun6 && echo "ERROR: Still running" || echo "Stopped"

# 3. Verify config file
echo "Checking config..."
cat ~/.config/wireguard/sumit.conf | head -3

# 4. Restart WireGuard
echo "Starting WireGuard..."
sudo wg-quick up ~/.config/wireguard/sumit.conf

# 5. Wait for tunnel to establish
sleep 3

# 6. Verify tunnel is up
echo "Verifying tunnel..."
ifconfig utun6 || echo "ERROR: Failed to start"

# 7. Clear SSH agent and reload key
echo "Reloading SSH key..."
ssh-add -D
ssh-add ~/.ssh/johnlee_k8s

# 8. Test connection
echo "Testing SSH connection..."
ssh -o ConnectTimeout=5 sysadmin@10.99.0.2 "hostname && whoami"
```

---

## What to Check When Connection Issues Occur

### Connection Lost - Diagnosis Flowchart

```
Connection lost to Debian?
├─ Can you ping 10.99.0.2?
│  ├─ YES → SSH problem (go to "SSH Issues" below)
│  └─ NO → Network problem
│     ├─ Can you ping 10.99.0.1?
│     │  ├─ YES → Debian specific issue (restart sshd: ssh sysadmin@10.99.0.2 "sudo systemctl restart ssh")
│     │  └─ NO → WireGuard problem
│     │     ├─ Is ifconfig utun6 running?
│     │     │  ├─ YES → Check handshake: sudo wg show
│     │     │  └─ NO → Restart: sudo wg-quick down && sudo wg-quick up
│     │     ├─ Can you ping 3.82.253.109 (Bastion public)?
│     │     │  ├─ YES → WireGuard config issue (check: cat ~/.config/wireguard/sumit.conf)
│     │     │  └─ NO → No internet (check network)
│
SSH Issues (ping works but SSH fails)
├─ Is SSH key loaded? ssh-add -l | grep johnlee
│  ├─ NO → Load it: ssh-add ~/.ssh/johnlee_k8s
│  └─ YES → Try direct: ssh -i ~/.ssh/johnlee_k8s sysadmin@10.99.0.2
├─ Get "Permission denied"?
│  └─ Fix permissions: chmod 600 ~/.ssh/johnlee_k8s
├─ Get "Connection refused"?
│  └─ SSH daemon down: ssh sysadmin@10.99.0.2 "sudo systemctl restart ssh"
└─ Verbose output: ssh -vvv sysadmin@10.99.0.2 (shows exact point of failure)
```

### Monitoring Commands for Debugging

```bash
# Real-time WireGuard status
watch -n 1 'sudo wg show'

# Monitor all network traffic (requires Debian access)
ssh sysadmin@10.99.0.2 'sudo tcpdump -i any port 22 or port 51820'

# Check Debian SSH daemon logs
ssh sysadmin@10.99.0.2 'sudo journalctl -u ssh -f'

# Monitor local WireGuard interface
watch -n 1 'ifconfig utun6'

# Check system routes (verify WireGuard routes)
netstat -rn | grep 10.99
```

---

## Regular Maintenance & Health Checks

### Daily Verification (Run before Terraform operations)

```bash
# Quick 30-second health check before any infrastructure changes
echo "=== Connection Health Check ===" && \
ifconfig utun6 | grep -q "inet 10.99.0.10" && echo "✅ WireGuard running" || echo "❌ WireGuard down" && \
ping -c 1 -W 2 10.99.0.2 &>/dev/null && echo "✅ Debian reachable" || echo "❌ Debian unreachable" && \
ssh -o ConnectTimeout=3 sysadmin@10.99.0.2 "echo OK" &>/dev/null && echo "✅ SSH working" || echo "❌ SSH failed"
```

### Weekly Checklist

- [ ] Test WireGuard connection: `ping 10.99.0.2`
- [ ] Verify SSH key is loaded: `ssh-add -l | grep johnlee`
- [ ] Check SSH permissions: `ls -la ~/.ssh/johnlee_k8s` (should be 600)
- [ ] Verify WireGuard config exists: `cat ~/.config/wireguard/sumit.conf | head -3`
- [ ] Check Bastion public IP reachable: `ping 3.82.253.109`

### Monthly Operations

```bash
# Full diagnostic report
echo "=== Monthly Infrastructure Health Report ===" && \
echo "Date: $(date)" && \
echo "---" && \
echo "WireGuard Status:" && \
ifconfig utun6 && \
echo "---" && \
echo "Bastion Connection:" && \
ping -c 3 10.99.0.1 && \
echo "---" && \
echo "Debian Connection:" && \
ping -c 3 10.99.0.2 && \
echo "---" && \
echo "SSH Key Status:" && \
ssh-add -l | grep johnlee && \
echo "---" && \
echo "SSH Access Test:" && \
ssh sysadmin@10.99.0.2 "echo 'Last SSH: '$(date)" && \
echo "---" && \
echo "Debian System Health:" && \
ssh sysadmin@10.99.0.2 "uname -a && uptime" && \
echo "Health check complete!"
```

### When to Restart WireGuard

Restart WireGuard if you experience:
- **Intermittent timeouts**: Packets drop sporadically
- **Degraded latency**: Response times increase significantly
- **Handshake timeout**: `sudo wg show` shows old handshake times
- **After network change**: WiFi to cellular switch, IP change, network location change
- **Before major operations**: Before `tofu apply` or critical infrastructure changes

**Quick restart:**
```bash
sudo wg-quick down ~/.config/wireguard/sumit.conf && \
sleep 2 && \
sudo wg-quick up ~/.config/wireguard/sumit.conf && \
echo "WireGuard restarted. Testing..." && \
ping -c 2 10.99.0.2
```

---

## Summary: The Flow

1. **Activate WireGuard** → Your Mac gets IP 10.99.0.10, encrypted tunnel established
2. **Traffic to 10.99.0.0/24** → Routed through encrypted WireGuard tunnel to Bastion
3. **Bastion routes to Debian** → WireGuard server forwards packets to 10.99.0.2
4. **SSH to Debian works** → Connection: Your Mac → WireGuard tunnel → Bastion → Debian
5. **Terraform SSH Jump** → Uses `sysadmin@10.99.0.1` as jump host, then SSH to `sysadmin@10.99.0.2` for kubeadm init
6. **Terraform provisions K8s** → Via SSH jump host through WireGuard tunnel to Debian
7. **kubectl access** → Works through kubeconfig file generated on Debian

**Deployment SSH Flow:**
```
Terraform on Your Mac
  ↓
SSH Agent (loads key: ~/.ssh/johnlee_k8s)
  ↓
WireGuard Tunnel (UDP:51820)
  ↓
Bastion WireGuard IP (10.99.0.1) - Routes to Debian
  ↓
Debian Host (10.99.0.2) - sysadmin@10.99.0.2
  ↓
kubeadm init / cluster setup
```

This architecture provides:
- ✅ **Encrypted**: All traffic through WireGuard tunnel (even Terraform SSH)
- ✅ **Secure**: SSH restricted to VPN subnet only (10.99.0.0/24)
- ✅ **Resilient**: FRP fallback tunnel available if WireGuard fails
- ✅ **Simple**: Single command to activate WireGuard (`wg-quick up`), then `tofu apply`
- ✅ **Correct bastion_ssh_user**: Must be "sysadmin" in terraform.tfvars for SSH jump host through VPN
