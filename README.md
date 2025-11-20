# Infrastructure as Code Specification

This repository manages the full lifecycle of the bastion (AWS jump host), VPN fabric, Debian host bootstrap, and Kubernetes cluster. The goal is a repeatable, idempotent workflow driven by OpenTofu so that any `tofu apply` can re-establish the desired state even after manual misconfiguration.

## Guiding Principles

1. **Single configuration file** – All environment-specific values live in `k8s/terraform.tfvars`. Examples:
   ```hcl
   aws_region                 = "us-east-1"
   jump_host_subnet_id        = "subnet-..."
   jump_host_vpc_id           = "vpc-..."
   debian_wireguard_private_key = "..."
   frp_token                    = "..."
   enable_frp_emergency         = false
   deploy_debian_host           = true
   deploy_kubernetes_cluster    = true
   ```
   A future phase will migrate secrets (WireGuard key, FRP token) to Google Secret Manager; until then, keep the tfvars file encrypted/protected.

2. **Elastic IP persistence** – The bastion EIP is managed by the `k8s/eips` module. Destroying the bastion never releases the allocation; apply phases automatically associate the instance with the persistent EIP output by that module.

3. **Pinned WireGuard identity** – The bastion’s WireGuard private/public key pair lives in `k8s/terraform.tfvars` (`bastion_wireguard_private_key` / `bastion_wireguard_public_key`) and is pushed down by the bootstrap script. If the instance is rebuilt, the key pair stays the same so Debian and laptops don’t need new configs.

4. **Bootstrap SSH tightening** – Use `jump_host_bootstrap_ssh_cidrs` for any public CIDRs that need SSH during provisioning. Terraform temporarily authorizes them (via AWS CLI) before the WireGuard bootstrap runs, and automatically revokes them once the VPN is up. The steady-state security group only allows SSH from `10.99.0.0/24`.

5. **FRP usage pattern** – The Debian FRP client is always enabled so it can immediately reconnect when the bastion-side FRP server is toggled on. The bastion’s security group keeps SSH closed; we rely on WireGuard for normal access, and only when `enable_frp_emergency=true` do we open ports 7005/7006 and start `frps` for break-glass access.

6. **Health-driven workflow** – Each apply phase verifies reachability:
   - **Bastion phase**: `module.aws_bastion` provisions EC2 + SG + WireGuard server + (optional) FRP.
   - **Debian phase**: `module.debian_host` stays enabled and ensures WireGuard/FRP/iptables on the Debian host. If SSH via WireGuard fails, the operator sets `enable_frp_emergency=true`, re-applies, and then reverts to false.
   - **Kubernetes phase**: `module.kubernetes_cluster` assumes the Debian host is reachable; failure indicates the previous phase must be fixed.

7. **Idempotence** – Re-running `tofu apply` must converge the system even if someone edited configs manually. For example, if the bastion `wg0.conf` lost a peer, the WireGuard provisioner re-uploads the config with the authoritative list from `var.wireguard_peers`. If Debian’s WireGuard IP drifts (10.99.0.20 vs 10.99.0.2) or the server key changes, Terraform rewrites both sides back to the canonical values before proceeding.

8. **Local laptop alignment** – Each operator keeps their `~/.config/wireguard/<peer>.conf` in sync with the tfvars values. If multiple people (e.g., John and Sumit) share the bastion, make sure *both* laptop public keys and IP assignments live in `wireguard_peers`. When either of you runs `tofu apply`, the WireGuard server is reset to match that list—if a peer is missing, it gets dropped from `/etc/wireguard/wg0.conf`.

## Desired End-to-End Workflow

1. **Prepare `k8s/terraform.tfvars`** with VPC/subnet IDs, the EIP allocation ID, WireGuard keys, FRP token, and set:
   ```hcl
   enable_frp_emergency      = false
   deploy_debian_host        = true
   deploy_kubernetes_cluster = true
   ```
2. **Bootstrap bastion (idempotent)**
   ```bash
   cd k8s
   tofu apply -target=module.eips        # first time only, or import existing EIP
   tofu apply -target=module.aws_bastion # provisions EC2 + WireGuard + optional FRP
   ```
   This ensures the bastion and the operator’s laptop are on the same VPN subnet; if the laptop config mismatches, `wg show` will show no handshake and the operator updates their local config before proceeding.

3. **Repair Debian host (automatic)**
   - Leave `deploy_debian_host=true`. Terraform connects via WireGuard; if unreachable, operator toggles `enable_frp_emergency=true` and re-applies to enable FRP until the host is fixed.
   - The module enforces `/etc/wireguard/wg0.conf`, restarts `wg-quick@wg0`, installs FRP client, and applies iptables rules.
   - Once successful, operator sets `enable_frp_emergency=false` and applies again (closing FRP ports).

4. **Install Kubernetes**
   - With Debian healthy, `module.kubernetes_cluster` installs containerd, kubeadm, networking, and addons.
   - Outputs expose kubeconfig and connection details; operators run `export KUBECONFIG=...` and verify the cluster.

5. **Ongoing operations** – Any future `tofu apply` re-validates each phase; if the bastion WireGuard config drifts, it’s rewritten; if Debian goes offline, Terraform fails early and the operator re-enables FRP; if Kubernetes needs upgrades, version bumps happen via variables. Before each apply, confirm:
   - `~/.config/wireguard/john.conf` matches `k8s/terraform.tfvars` (public key + endpoint).
   - `wg show` on the laptop reports a recent handshake with `10.99.0.1`.
   - `ssh bastion-admin` works using the per-host `known_hosts.paijump` file.

## Future Enhancements
- Implement a health probe (e.g., null_resource with `local-exec`) to automatically toggle FRP when WireGuard is down.
- Migrate sensitive variables to Google Secret Manager and reference them via `terraform-provider-google` data sources.
- Provide a small local script to regenerate the laptop WireGuard config and test connectivity pre-apply. *(Initial versions live under `scripts/refresh_wireguard.py` and `scripts/vpn_health_check.py`; future work may fold them into a single CLI.)*

## Helper Scripts
- `python scripts/refresh_wireguard.py --peer <name>` – regenerates `~/.config/wireguard/<name>.conf` from `k8s/terraform.tfvars` and (optionally) restarts the tunnel with `--apply`. Use this whenever you change `wireguard_peers`, the bastion IP, or the server key.
- `python scripts/vpn_health_check.py` – pings `10.99.0.1`, then runs `ssh bastion-admin` and `ssh debian-vpn` to confirm that the WireGuard path is healthy before (or after) a `tofu apply`.

> **Note:** The bootstrap/lockdown helpers rely on the AWS CLI (matching your Terraform credentials) to add/revoke temporary ingress rules whenever `jump_host_bootstrap_ssh_cidrs` is non-empty.

## SSH Host Reference

- `bastion` – `newuser@10.99.0.1` via WireGuard (key: `~/.ssh/jumpproxy`). Use this for routine bastion access once your laptop tunnel is up.
- `bastion-admin` – `admin@10.99.0.1` via WireGuard (key: `~/.ssh/id_ed25519`). Reserved for provisioning/maintenance (Terraform connects as this user).
- `bastion-admin-external` – `admin@3.82.253.109`. Only useful when you temporarily allow public SSH (e.g., during bootstrap or FRP emergency). Otherwise blocked by the SG after lockdown.
- `debian-vpn` – `sysadmin@10.99.0.2` through the bastion jump host (`bastion-admin`). Works whenever the WireGuard fabric is healthy; this is the normal path into Debian.
- `debian-frp` – `sysadmin@localhost:7006` tunneled through `bastion`. Only works when `enable_frp_emergency=true` (the bastion FRP server is running).
- `debian-frp-external` – same as above, but via `bastion-admin-external` for situations where your laptop can’t reach the VPN network at all.
- `debian-local` – `sysadmin@192.168.1.123` on the LAN. Only reachable when you manually open iptables for local access (e.g., via console work).

> **Note:** The automatic SSH bootstrap/lockdown flow requires the AWS CLI to be available in your shell environment (same credentials/profile Terraform uses), because Terraform invokes `aws ec2 authorize-security-group-ingress` / `revoke-security-group-ingress` under the hood.

## Operational Notes / Gotchas

- **Do not change WireGuard keys on the servers manually.** If you rotate keys, update `k8s/terraform.tfvars` first and let OpenTofu push the new values everywhere (bastion, Debian, laptop config). Mismatched keys were the main reason prior attempts failed.
- **Debian must keep `frpc` enabled.** The client service stays running even when the bastion-side FRP server is off; when `enable_frp_emergency=true`, the server port opens and the tunnel connects automatically. Disabling `frpc` means “FRP on” applies will never succeed.
- **Laptop/bastion SSH config relies on `~/.ssh/known_hosts.paijump`.** When the bastion is rebuilt, seed the new host keys with `ssh-keyscan 10.99.0.1 10.99.0.2 >> ~/.ssh/known_hosts.paijump` before attempting JumpHost connections; otherwise strict host checking will hang applies.
