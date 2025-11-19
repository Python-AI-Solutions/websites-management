# Debian Host Deployment Plan with FRP Emergency Access

**Status:** 🟡 DESIGN & IMPLEMENTATION (In Progress)
**Created:** 2025-11-18
**Document Type:** Infrastructure Architecture & Deployment Guide

---

## 🎯 Problem Statement

**Current Situation (Blocking):**
- Debian host is inaccessible
- VPN IP misconfigured: `10.99.0.2` (should be `10.99.0.20`)
- Cannot access the host to fix the VPN configuration
- Classic chicken-and-egg problem: need access to set up access

**System Requirement:**
> Infrastructure as Code solution needed to set up a Debian host that makes itself a VPN peer, sets up reverse tunnel access, and restricts all but necessary ports when initial SSH access is unavailable.

---

## 🏗️ Architecture Overview

### Current State
```
┌─────────────────────────────────────────┐
│  Local Workstation                      │
│  (can't reach Debian)                   │
└─────────────────────────────────────────┘
                   ❌
         (No WireGuard access)
                   ❌
┌─────────────────────────────────────────┐
│  AWS Bastion (Jumphost)                 │
│  ✅ Reachable from workstation          │
│  ✅ Has FRP server capability           │
└─────────────────────────────────────────┘
                   ❌
         (FRP server disabled)
                   ❌
┌─────────────────────────────────────────┐
│  Debian Host                            │
│  ❌ VPN IP misconfigured (.2 vs .20)   │
│  ❌ FRP client configured but unused    │
│  ❌ Cannot be reached via VPN           │
└─────────────────────────────────────────┘
```

### Target State (After Deployment)
```
┌─────────────────────────────────────────┐
│  Local Workstation                      │
│  ✅ Can reach Debian via WireGuard      │
│  ✅ All access via VPN (normal)         │
│  🟢 FRP only used in emergencies        │
└─────────────────────────────────────────┘
         (WireGuard VPN - Normal)
         (10.99.0.0/24 subnet)
                   ✅
┌─────────────────────────────────────────┐
│  AWS Bastion (Jumphost)                 │
│  ✅ Configured with FRP server          │
│  🟢 FRP port (7000) CLOSED (normal)     │
│  ✅ Opened only on emergency            │
└─────────────────────────────────────────┘
           (FRP - Emergency Only)
                   ✅
┌─────────────────────────────────────────┐
│  Debian Host                            │
│  ✅ VPN IP correct: 10.99.0.20          │
│  ✅ FRP client ready (not needed)       │
│  ✅ Accessible via WireGuard            │
│  ✅ Port restrictions applied           │
└─────────────────────────────────────────┘
```

### The FRP Emergency Workflow
```
User tries: tofu apply
       ↓
[Health Check: Can we reach Debian?]
       ↓
    ┌──YES──┐             ┌──NO──┐
    ↓       ✅            ↓      ❌
 Normal    (FRP stays    Auto-enable
 Deploy    disabled)      FRP
    ↓                     ↓
[K8s, apps  [User gets    User: ssh -J bastion
 deploy]    emergency    debian for manual fix
    ↓       access]      ↓
 ✅ Done    ↓          Fix issue
           User fixes   (e.g., VPN IP)
           Debian       ↓
           (via FRP)    tofu apply
           ↓            (again)
           tofu apply   ↓
           (again)      ✅ Check passes
           ↓            ↓
         ✅ Check       FRP auto-disabled
         passes         ↓
           ↓          ✅ Done
         FRP auto-
         disabled
           ↓
         ✅ Done
```

---

## 📋 IaC Implementation Strategy

### Step 1: FRP Emergency Access Setup

**What it does:** Provides temporary double-hop access when normal WireGuard access fails

**Prerequisites:**
- ✅ AWS bastion host exists
- ✅ Debian host has FRP client pre-installed (in user_data)
- ✅ FRP server can be toggled on/off via Terraform variable

**Terraform Implementation:**

File: `k8s/aws/frp.tf`
```hcl
variable "enable_frp_emergency" {
  description = "Enable FRP server for emergency Debian access (default: false, only enable if Debian check fails)"
  type        = bool
  default     = false
}

# Open FRP server port (7000) only when emergency access needed
resource "aws_security_group_rule" "frp_server_port" {
  count             = var.enable_frp_emergency ? 1 : 0
  type              = "ingress"
  from_port         = 7000
  to_port           = 7000
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # Debian will connect from anywhere
  security_group_id = aws_security_group.bastion.id
  description       = "FRP server port - EMERGENCY ONLY, auto-enabled by tofu"
}

# Start FRP server when enabled
resource "aws_instance" "bastion" {
  # ... existing bastion config ...

  user_data = base64encode(templatefile("${path.module}/scripts/bastion-init.sh", {
    enable_frp = var.enable_frp_emergency
    # ... other variables
  }))
}
```

File: `k8s/aws/scripts/bastion-init.sh`
```bash
#!/bin/bash
# FRP Server Management

ENABLE_FRP="${enable_frp}"

if [ "$ENABLE_FRP" = "true" ]; then
  echo "[$(date)] Starting FRP server on port 7000"
  # Start FRP server (assumes frp already installed)
  systemctl start frp
else
  echo "[$(date)] Keeping FRP server disabled (normal operation)"
  systemctl stop frp || true
fi
```

**Usage:**
```bash
# Normal operation (FRP disabled)
cd k8s
tofu apply
# FRP stays disabled

# Emergency (if Debian check fails, FRP auto-enabled)
# User gets emergency access:
ssh -J ubuntu@aws-bastion ubuntu@debian-host
# User fixes Debian configuration
# Then tofu apply again
```

---

### Step 2: Debian Host Configuration

**What it does:** Bootstrap Debian as a VPN peer with FRP client and port restrictions

**Prerequisites:**
- ✅ Debian host exists (can be AWS or external)
- ✅ Has network access to AWS bastion
- ✅ Has SSH configured for initial access

**Terraform Implementation:**

File: `k8s/debian/variables.tf`
```hcl
variable "debian_wireguard_ip" {
  description = "WireGuard VPN IP for Debian host (MUST be 10.99.0.20)"
  type        = string
  default     = "10.99.0.20"  # THE FIX
}

variable "debian_wireguard_private_key" {
  description = "Debian WireGuard private key"
  type        = string
  sensitive   = true
}

variable "debian_host_address" {
  description = "Debian host IP or hostname (for SSH)"
  type        = string
}

variable "bastion_host_address" {
  description = "AWS bastion internal IP (for bastion_host in SSH connection)"
  type        = string
}

variable "debian_ssh_key" {
  description = "Path to SSH private key for Debian access"
  type        = string
}
```

File: `k8s/debian/main.tf`
```hcl
# Fix Debian WireGuard configuration via remote-exec
resource "null_resource" "debian_wireguard_config" {
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Updating WireGuard configuration...'",
      "sudo mkdir -p /etc/wireguard",
      "echo '[Interface]' | sudo tee /etc/wireguard/wg0.conf > /dev/null",
      "echo 'PrivateKey = ${var.debian_wireguard_private_key}' | sudo tee -a /etc/wireguard/wg0.conf > /dev/null",
      "echo 'Address = ${var.debian_wireguard_ip}/32' | sudo tee -a /etc/wireguard/wg0.conf > /dev/null",
      "echo '' | sudo tee -a /etc/wireguard/wg0.conf > /dev/null",
      "echo 'Restarting WireGuard...'",
      "sudo systemctl restart wg-quick@wg0 || sudo wg-quick up wg0",
      "sleep 2",
      "echo 'Verifying WireGuard interface...'",
      "sudo wg show"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.debian_ssh_key)
      host        = var.debian_host_address
      bastion_host = var.bastion_host_address
      bastion_user = "ubuntu"
    }
  }

  depends_on = [aws_instance.bastion]  # Wait for bastion first
}

# Configure FRP client on Debian
resource "null_resource" "debian_frp_client" {
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Setting up FRP client...'",
      "sudo mkdir -p /etc/frp",
      "echo '[common]' | sudo tee /etc/frp/frpc.ini > /dev/null",
      "echo 'server_addr = ${var.bastion_host_address}' | sudo tee -a /etc/frp/frpc.ini > /dev/null",
      "echo 'server_port = 7000' | sudo tee -a /etc/frp/frpc.ini > /dev/null",
      "echo 'token = secret' | sudo tee -a /etc/frp/frpc.ini > /dev/null",
      "echo '' | sudo tee -a /etc/frp/frpc.ini > /dev/null",
      "echo '[ssh]' | sudo tee -a /etc/frp/frpc.ini > /dev/null",
      "echo 'type = tcp' | sudo tee -a /etc/frp/frpc.ini > /dev/null",
      "echo 'local_ip = 127.0.0.1' | sudo tee -a /etc/frp/frpc.ini > /dev/null",
      "echo 'local_port = 22' | sudo tee -a /etc/frp/frpc.ini > /dev/null",
      "echo 'remote_port = 2222' | sudo tee -a /etc/frp/frpc.ini > /dev/null",
      "echo 'FRP client configured'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.debian_ssh_key)
      host        = var.debian_host_address
      bastion_host = var.bastion_host_address
      bastion_user = "ubuntu"
    }
  }

  depends_on = [null_resource.debian_wireguard_config]
}

# Port restrictions via iptables
resource "null_resource" "debian_port_restrictions" {
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Restricting ports...'",
      "# Allow SSH from bastion only",
      "sudo iptables -I INPUT -p tcp --dport 22 -s ${var.bastion_host_address} -j ACCEPT",
      "sudo iptables -I INPUT -p tcp --dport 22 -j DROP",
      "# Allow WireGuard from anywhere",
      "sudo iptables -I INPUT -p udp --dport 51820 -j ACCEPT",
      "# Block everything else",
      "sudo iptables -I INPUT -j DROP",
      "echo 'Rules applied'",
      "sudo iptables -L | head -20"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.debian_ssh_key)
      host        = var.debian_host_address
      bastion_host = var.bastion_host_address
      bastion_user = "ubuntu"
    }
  }

  depends_on = [null_resource.debian_frp_client]
}
```

---

### Step 3: Single Tofu Apply Orchestration

**What it does:** One command that checks Debian health and auto-enables FRP if needed

**Implementation:** Root `k8s/main.tf`

```hcl
# Health check: Can we reach Debian via WireGuard?
locals {
  # Try to ping Debian - if it fails, enable FRP
  debian_accessible = try(
    exec(
      "ping -c 1 -W 1 10.99.0.20 >/dev/null 2>&1 && echo true || echo false"
    ) == "true",
    false
  )

  enable_frp = !local.debian_accessible
}

# Module 1: AWS Bastion (with FRP toggle)
module "aws_bastion" {
  source = "./aws"

  enable_frp_emergency = local.enable_frp
  # ... other variables
}

# Module 2: Debian Host (depends on bastion)
module "debian_host" {
  source = "./debian"

  bastion_host_address = module.aws_bastion.bastion_internal_ip
  debian_host_address  = var.debian_host_address
  debian_wireguard_ip  = "10.99.0.20"
  # ... other variables

  depends_on = [module.aws_bastion]
}

# Module 3: Kubernetes (depends on Debian)
module "kubernetes_cluster" {
  source = "./kubernetes"

  # ... existing variables
  depends_on = [module.debian_host]
}

# Output for user
output "deployment_status" {
  value = {
    debian_accessible = local.debian_accessible
    frp_enabled      = local.enable_frp
    action           = local.enable_frp ? "FRP enabled for emergency access" : "Normal deployment, FRP disabled"
  }
}
```

---

## 📝 Deployment Procedures

### NORMAL Deployment (Everything Works)
```bash
cd k8s

# Initialize Terraform
tofu init

# Plan to see what will happen
tofu plan

# Apply (if everything looks good)
tofu apply

# Expected output:
# Debian health check: PASS ✅
# FRP enabled: false
# Actions: AWS bastion deployed, Debian configured, K8s cluster deployed
```

### EMERGENCY Deployment (Debian Locked)
```bash
cd k8s

# First attempt
tofu apply

# Health check: FAIL ❌
# FRP auto-enabled on bastion
# Output: "FRP enabled for emergency access"

# User now has emergency access:
ssh -J ubuntu@aws-bastion ubuntu@debian-host

# Inside Debian, fix the issue:
# (e.g., VPN IP configuration is already fixed by Terraform)

# Verify WireGuard is working:
sudo systemctl status wg-quick@wg0
sudo wg show

# Test connectivity:
ping 10.99.0.1  # Should work if VPN is up

# Exit from Debian
exit

# On local machine, test access via VPN:
ping 10.99.0.20

# If ping works, run tofu apply again:
cd k8s
tofu apply

# This time: PASS ✅
# Health check succeeds
# FRP auto-disabled
# Deployment continues
```

---

## 🚨 Port Configuration

### Debian Host - Allowed Ports

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | AWS Bastion (10.x.x.x) | SSH for admin access |
| 51820 | UDP | Internet | WireGuard VPN |
| 7001 | TCP | AWS Bastion | FRP client reverse tunnel (if FRP enabled) |

### Debian Host - Blocked Ports
- All other ports: BLOCKED by default via iptables

### AWS Bastion - Special Ports

| Port | Protocol | Status | Condition |
|------|----------|--------|-----------|
| 7000 | TCP | CLOSED (normal) | FRP server port only opens when `enable_frp_emergency=true` |
| 22 | TCP | OPEN | SSH from workstations |

---

## 🔧 VPN Peer Configuration

### The Critical Fix

**Current (Wrong):**
```
Debian WireGuard IP: 10.99.0.2
Expected IP: 10.99.0.20
Status: ❌ MISMATCH - Debian can't be reached
```

**Target (Correct):**
```
Debian WireGuard IP: 10.99.0.20
Expected IP: 10.99.0.20
Status: ✅ MATCH - Debian reachable via VPN
```

**How Fixed via Terraform:**
- Terraform sets `var.debian_wireguard_ip = "10.99.0.20"`
- Remote-exec provisioner updates `/etc/wireguard/wg0.conf` on Debian
- Restarts WireGuard service
- Verification: `sudo wg show` confirms IP

**Why Via Terraform (Not Manual):**
Infrastructure as Code ensures that fixes are reproducible and deterministic - when Terraform applies, it works the same way every time without requiring manual intervention or tribal knowledge.

---

## 📚 Runbook: FRP Emergency Access

### When to Use
- Can't reach Debian via WireGuard (ping 10.99.0.20 fails)
- Need to debug or fix Debian configuration
- Locked out and need emergency access

### Step-by-Step Procedure

**Step 1: Enable FRP Emergency Access**
```bash
cd k8s

# Run tofu apply - it will detect Debian is unreachable
# and auto-enable FRP
tofu apply

# Wait ~5 minutes for FRP server to start on bastion
# Watch the output for: "FRP enabled for emergency access"
```

**Step 2: Access Debian via FRP Double-Hop**
```bash
# SSH to bastion first, then access Debian through FRP
ssh -J ubuntu@aws-bastion ubuntu@debian-host

# Alternative method:
ssh ubuntu@aws-bastion
# Then from bastion:
# If FRP is set up correctly, Debian is accessible via localhost:2222
```

**Step 3: Debug and Fix**
```bash
# Once inside Debian, check status:
sudo systemctl status wg-quick@wg0
sudo wg show

# Check WireGuard configuration:
sudo cat /etc/wireguard/wg0.conf | grep -i address

# If IP is wrong, Terraform should have fixed it automatically
# If there are other issues, fix them manually

# Verify internet access through VPN:
curl -I https://google.com
ping 8.8.8.8

# Test SSH access from bastion works:
ssh -J ubuntu@aws-bastion ubuntu@debian-host  # Should work
```

**Step 4: Close Emergency Access**
```bash
# Exit from Debian
exit

# Back on local machine, verify VPN access works:
ping 10.99.0.20

# If ping works, disable FRP emergency access:
cd k8s
tofu apply  # This time Debian check will PASS

# FRP will auto-disable
# Verify FRP is disabled:
aws ec2 describe-security-groups --group-ids sg-xxx | grep 7000
# Should show FRP rule is gone
```

**Step 5: Verify Everything Works**
```bash
# All future access via normal WireGuard VPN:
ssh ubuntu@10.99.0.20

# Verify Debian is part of the cluster:
kubectl get nodes

# Done! FRP is closed, normal operation resumed
```

---

## ✅ Success Criteria

**Debian Deployment Plan is DONE when:**

1. ✅ Terraform code compiles and validates
   ```bash
   cd k8s
   tofu init
   tofu validate
   # No errors
   ```

2. ✅ Single `tofu apply` can deploy everything
   ```bash
   cd k8s
   tofu apply
   # Completes without errors
   ```

3. ✅ Debian accessible via WireGuard
   ```bash
   ping 10.99.0.20
   # Should respond
   ```

4. ✅ VPN IP is correct (10.99.0.20)
   ```bash
   ssh ubuntu@10.99.0.20 "sudo wg show | grep Address"
   # Should show: 10.99.0.20/32
   ```

5. ✅ FRP emergency access works (if tested)
   ```bash
   # Simulate Debian down, enable FRP manually
   tofu apply -var="enable_frp_emergency=true"
   # Can access via: ssh -J ubuntu@aws-bastion ubuntu@debian-host
   ```

6. ✅ FRP auto-disables when not needed
   ```bash
   # After Debian is healthy again
   tofu apply  # Debian check passes
   # FRP automatically disabled
   aws ec2 describe-security-groups | grep 7000
   # No result (port closed)
   ```

---

## 📊 Progress Tracking

**Design Document:** ✅ COMPLETE (this document)

**Next Steps:**
1. ⏳ TASK 2: Merge /aws into /k8s directory
2. ⏳ TASK 3: Implement Terraform code from this plan
3. ⏳ TASK 4: Add audit logging
4. ⏳ Deploy and test

---

## 📎 Appendix: Terraform Code Summary

### Files to Create
- `k8s/aws/frp.tf` - FRP emergency access toggle
- `k8s/debian/main.tf` - Debian configuration
- `k8s/debian/variables.tf` - Debian variables
- `k8s/debian/outputs.tf` - Debian outputs
- Root `k8s/main.tf` - Update with modules and health check
- Root `k8s/variables.tf` - Add new variables

### Code Templates
Terraform code examples provided in implementation phase:
- Module structure and orchestration
- Provisioner configurations
- Security group rules
- Systemd service configurations

---

**Document Status:** 🟡 IMPLEMENTATION IN PROGRESS
**Last Updated:** 2025-11-19
**Next:** Resolve module integration blockers and validate configuration

