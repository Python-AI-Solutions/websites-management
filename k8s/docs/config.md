# Configuration Reference

Complete guide to `terraform.tfvars` configuration options.

## Overview

Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

**Never commit `terraform.tfvars` to git** - it contains secrets.

## WireGuard Keys

```hcl
debian_wireguard_private_key  = "YOUR_DEBIAN_WIREGUARD_PRIVATE_KEY_HERE"
bastion_wireguard_private_key = "YOUR_BASTION_WIREGUARD_PRIVATE_KEY_HERE"
bastion_wireguard_public_key  = "YOUR_BASTION_WIREGUARD_PUBLIC_KEY_HERE"
```

**Generate keys:**
```bash
# Generate private key
wg genkey > wireguard-private.key

# Derive public key from private
wg pubkey < wireguard-private.key > wireguard-public.key

# Display base64 encoded value for config
cat wireguard-private.key
```

**Format:** Base64-encoded 32-byte keys

## FRP Emergency Access

```hcl
frp_token = "frp-auth-token-that-is-super-secret"
```

**Purpose:** Authentication token for FRP reverse proxy (emergency access)

**Generate strong token:**
```bash
openssl rand -hex 32
```

**Length:** 32+ characters (random)

## SSH Configuration

### Jump User

```hcl
jump_host_jump_user = "ubuntu"
```

**Options:**
- `ubuntu` - Ubuntu AMI (default)
- `admin` - Debian AMI
- `ec2-user` - Amazon Linux

**Must match the SSH user for your chosen AMI**

### SSH Keys

```hcl
jump_host_jump_user_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJxx... user@host"
jump_host_admin_authorized_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHxx... user@host"
```

**Get your SSH public key:**
```bash
cat ~/.ssh/id_ed25519.pub
```

**Or generate new key:**
```bash
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

**Format:** Full key with type and comment (e.g., `ssh-ed25519 AAAA... user@host`)

### AWS Key Pair

```hcl
jump_host_key_name = "your-aws-key-pair-name"
```

**Existing AWS key pair to use for EC2 access**

**Create if needed:**
```bash
aws ec2 create-key-pair --key-name my-key --region us-east-1 > my-key.json
# Extract private key
jq -r '.PrivateKeyMaterial' my-key.json > ~/.ssh/my-key.pem
chmod 600 ~/.ssh/my-key.pem
```

## Bootstrap Security

```hcl
jump_host_bootstrap_ssh_cidrs = ["51.37.143.220/32", "223.190.80.154/32"]
```

**CIDRs allowed for initial SSH deployment**

**Find your IP:**
```bash
curl https://ifconfig.me
# Result: 1.2.3.4
# Use: "1.2.3.4/32"
```

**Multiple IPs:**
```hcl
jump_host_bootstrap_ssh_cidrs = [
  "1.2.3.4/32",        # Your home IP
  "5.6.7.8/32",        # Your work IP
  "10.0.0.0/8"         # Your corporate network (caution: wide range)
]
```

## WireGuard Peers

```hcl
wireguard_peers = [
  {
    name                 = "debian-host"
    public_key           = "WIREGUARD_PUBLIC_KEY"
    allowed_ips          = ["10.99.0.2/32"]
    persistent_keepalive = 25
  },
  {
    name                 = "your-laptop"
    public_key           = "YOUR_LAPTOP_WIREGUARD_PUBLIC_KEY"
    allowed_ips          = ["10.99.0.15/32"]
    persistent_keepalive = 25
  }
]
```

### For Each Team Member

1. **Generate WireGuard keys:**
   ```bash
   wg genkey | tee client-private.key | wg pubkey > client-public.key
   ```

2. **Add to wireguard_peers:**
   ```hcl
   {
     name                 = "alice-laptop"
     public_key           = "ALICE_PUBLIC_KEY_BASE64"
     allowed_ips          = ["10.99.0.10/32"]
     persistent_keepalive = 25
   }
   ```

3. **Share configuration securely** (NOT in git):
   ```
   [Interface]
   PrivateKey = ALICE_PRIVATE_KEY
   Address = 10.99.0.10/32
   DNS = 8.8.8.8

   [Peer]
   PublicKey = BASTION_PUBLIC_KEY
   AllowedIPs = 10.99.0.0/24, 10.0.0.0/8
   Endpoint = BASTION_PUBLIC_IP:51820
   PersistentKeepalive = 25
   ```

### IP Allocation

- `10.99.0.1/32` - Bastion WireGuard endpoint
- `10.99.0.2/32` - Debian Kubernetes host
- `10.99.0.10-20/32` - Team members
- `10.99.0.100-255/32` - Future allocation

**Each peer gets unique IP in the VPN subnet**

## Kubernetes Control Plane

```hcl
control_plane_endpoint = "192.168.1.123:6443"
```

**Internal IP of Kubernetes API server**

**Format:** `INTERNAL_IP:6443`

Example: `10.99.0.2:6443` (Debian host internal IP)

## Bastion SSH User

```hcl
bastion_ssh_user = "ubuntu"
```

**Must match `jump_host_jump_user`** - used for post-deployment access

## Feature Flags

```hcl
enable_frp_emergency = true
deploy_debian_host   = true
deploy_kubernetes_cluster = true
```

| Flag | Purpose | Default |
|------|---------|---------|
| `enable_frp_emergency` | Enable FRP reverse proxy for emergency access | `true` |
| `deploy_debian_host` | Deploy Debian host in VPC | `true` |
| `deploy_kubernetes_cluster` | Deploy Kubernetes on Debian host | `true` |

**Set to `false` to skip deployment steps** (useful for incremental builds)

## Complete Example

```hcl
# WireGuard Keys (generate with: wg genkey | wg pubkey)
debian_wireguard_private_key  = "4Cjlvtm62BQufiTxlTSsv61DtkVRMVjw03nsuxtDBG0="
bastion_wireguard_private_key = "yG0xWHFCfVRotwhJ+VQHD52ow4M6I1iCLeSvE6bYtVc="
bastion_wireguard_public_key  = "39oLcmw2XRX57PguWfsqlZmURajuRJQiUUj+mvqIWhU="

# Emergency access
frp_token = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"

# SSH User
jump_host_jump_user = "ubuntu"

# SSH Keys
jump_host_jump_user_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJTWy8XZL+zgsAYuk0xB7ceVIZYqvQQMF24ccnbhXEWk john@laptop"
jump_host_admin_authorized_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHk+XuQ8aeagMG3qnJHrDczpjwSwMa4gRqCI8oNpJILu admin@admin"

# AWS Key Pair Name
jump_host_key_name = "my-aws-key"

# Bootstrap CIDRs (restrict to your IP)
jump_host_bootstrap_ssh_cidrs = ["1.2.3.4/32"]

# WireGuard Peers
wireguard_peers = [
  {
    name                 = "debian-host"
    public_key           = "LpSeYGB1WDHHLr2bwrZFsVcjCAnXdwCs7xF9WhmbX1s="
    allowed_ips          = ["10.99.0.2/32"]
    persistent_keepalive = 25
  },
  {
    name                 = "john-laptop"
    public_key           = "SK5gYFUBINcDwtARBLmtGVcr1hv2N68QDmXWx4Gt3Dc="
    allowed_ips          = ["10.99.0.15/32"]
    persistent_keepalive = 25
  }
]

# Kubernetes
control_plane_endpoint = "10.99.0.2:6443"
bastion_ssh_user       = "ubuntu"

# Features
enable_frp_emergency      = true
deploy_debian_host        = true
deploy_kubernetes_cluster = true
```

## Validation

Verify your configuration:

```bash
# Check syntax
terraform validate

# Review values that will be used
terraform plan | grep -E "^\+" | head -20

# Check for typos
grep -E "YOUR_|CHANGE_ME" terraform.tfvars
# Should return nothing
```

## Troubleshooting

### "Invalid WireGuard key format"
- Keys must be base64-encoded (generated by `wg genkey`)
- Check key length (should be 44 characters with = padding)

### "SSH key format incorrect"
- Must start with `ssh-ed25519` or `ssh-rsa`
- Must include username/comment at end
- Get correct format: `cat ~/.ssh/id_ed25519.pub`

### "CIDR validation error"
- CIDRs must end with `/32` (single IP) or `/24` (network range)
- Format: `"1.2.3.4/32"` with quotes and slash

### "Control plane endpoint invalid"
- Must be `IP:6443` format
- Use internal IP of Kubernetes host
- Port must be 6443 (Kubernetes API port)

## Next Steps

1. Fill in all required values in `terraform.tfvars`
2. Run `terraform validate` to check syntax
3. Run `terraform plan` to review resources
4. See [setup.md](./setup.md) for deployment steps

