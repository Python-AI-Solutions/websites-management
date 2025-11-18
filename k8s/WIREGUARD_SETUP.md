# WireGuard Setup Documentation

## Overview

This document describes the WireGuard VPN overlay network topology and key management workflow for the Kubernetes infrastructure.

## Network Topology

```
┌─────────────────────┐
│   Developer Laptop  │
│   (10.99.0.10/32)   │
│      [Sumit]        │
└──────────┬──────────┘
           │
           │ WireGuard VPN
           │ UDP 51820
           │
┌──────────▼──────────┐
│   AWS Bastion Host  │
│    (10.99.0.1/24)   │
│  [Jump/WG Server]   │
└──────────┬──────────┘
           │
           │ WireGuard VPN
           │
┌──────────▼──────────┐
│  Debian K8s Host    │
│   (10.99.0.20/32)   │
│    [K8s Cluster]    │
└─────────────────────┘

Additional Peers:
- John's Laptop: 10.99.0.15/32
```

## IP Allocation

| Host | WireGuard IP | Purpose |
|------|--------------|---------|
| AWS Bastion | 10.99.0.1/24 | WireGuard server, jump host |
| Sumit's Laptop | 10.99.0.10/32 | Developer access |
| John's Laptop | 10.99.0.15/32 | Developer access |
| Debian K8s Host | 10.99.0.20/32 | Kubernetes cluster |
| Reserved | 10.99.0.21-254 | Future hosts/services |

## Key Management

### Debian Host Keys

The Debian host WireGuard keys were generated on November 13, 2025:

- **Location**: `k8s/debian-wireguard-keys.md` (private key stored securely)
- **Public Key**: `h/tFyZVd0xt8WiPrNycmtmcPfk2+l97GCmHvGMiqsjY=`
- **Registered in**: `aws/wireguard-peers.auto.tfvars.json`

### Key Generation Process

For new peers, follow these steps:

1. **Generate key pair**:
   ```bash
   wg genkey | tee private.key | wg pubkey > public.key
   ```

2. **Add to WireGuard peers configuration**:
   - Edit `aws/wireguard-peers.auto.tfvars.json`
   - Add new peer entry with public key and assigned IP

3. **Apply AWS configuration**:
   ```bash
   cd aws
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/gcp-service-account.json"
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   tofu apply
   ```

4. **Configure the peer device**:
   - Use the private key in the peer's WireGuard config
   - Server public key: Get from bastion with `ssh bastion-admin 'sudo cat /etc/wireguard/server.pub'`

### Key Rotation

To rotate keys for any peer:

1. Generate new key pair (as above)
2. Update `aws/wireguard-peers.auto.tfvars.json` with new public key
3. Apply terraform changes to update server
4. Update peer's local configuration with new private key
5. Restart WireGuard on the peer

## Firewall Configuration

The Debian host firewall is configured via Terraform with the following allowed ports:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH access |
| 80 | TCP | HTTP (Traefik ingress) |
| 443 | TCP | HTTPS (Traefik ingress) |
| 6443 | TCP | Kubernetes API |
| 30000-32767 | TCP | Kubernetes NodePort services |
| 51820 | UDP | WireGuard VPN |

Additional rules:
- Every allowed port listed above is limited to the WireGuard subnet (10.99.0.0/24)
- Established connections are allowed
- ICMP (ping) is allowed

To modify allowed ports, edit `debian_allowed_ports` in `k8s/variables.tf` or override the variable via `terraform.tfvars`/`-var`.

## Terraform Variables

Key WireGuard-related variables in `k8s/variables.tf`:

- `wireguard_server_public_key`: Public key of the WireGuard server (bastion)
- `debian_allowed_ports`: List of ports to allow through the firewall

## Testing Connectivity

After setup, test connectivity:

1. **From laptop to bastion**:
   ```bash
   ping 10.99.0.1
   ```

2. **From laptop to Debian host**:
   ```bash
   ping 10.99.0.20
   ```

3. **Access Kubernetes API via WireGuard**:
   ```bash
   kubectl --kubeconfig=./kubeconfig get nodes
   ```

## Troubleshooting

### WireGuard not connecting

1. Check WireGuard status on Debian host:
   ```bash
   ssh -J bastion debian-host 'sudo wg show'
   ```

2. Check if WireGuard service is running:
   ```bash
   ssh -J bastion debian-host 'sudo systemctl status wg-quick@wg0'
   ```

3. Verify firewall rules:
   ```bash
   ssh -J bastion debian-host 'sudo iptables -L -n -v'
   ```

### Key mismatch errors

1. Verify public keys match in:
   - `aws/wireguard-peers.auto.tfvars.json` (peer public keys)
   - Debian host's `/etc/wireguard/wg0.conf` (server public key)

2. Regenerate and update keys if needed (see Key Rotation section)

## Security Considerations

1. **Private keys**: Never commit private keys to git
2. **Access control**: WireGuard peers are the primary access control
3. **Firewall**: Additional layer of defense with iptables rules
4. **Key rotation**: Rotate keys periodically or when team members change

## Collaboration Workflow

When team members need access:

1. They generate their own WireGuard key pair locally
2. They provide their public key and preferred IP (or use next available)
3. Admin adds their peer entry to `aws/wireguard-peers.auto.tfvars.json`
4. Admin applies terraform changes
5. Admin provides them with server public key and endpoint
6. They configure their local WireGuard client

## References

- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)
- [WireGuard on Debian](https://wiki.debian.org/WireGuard)
- Project-specific keys: `k8s/debian-wireguard-keys.md`
