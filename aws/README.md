# AWS infrastructure

This configuration captures the existing jump host EC2 instance (`i-08da10999e8ebcefa`) together with its elastic IP. The configuration is written for [OpenTofu](https://opentofu.org) and assumes credentials are already available via the default AWS CLI configuration.

## Getting started

```bash
cd aws
tofu init
```

## Import the existing resources

Before running any plan or apply you must import the currently running resources so that OpenTofu links them to the configuration instead of trying to recreate them.

```bash
# Import the security group
tofu import aws_security_group.jump_host sg-0941550cf497338b7

# Import the EC2 instance
tofu import aws_instance.jump_host i-08da10999e8ebcefa

# Import the elastic IP allocation
tofu import aws_eip.jump_host eipalloc-050f076c6d971ed4b
```

Once both imports succeed, verify that the state matches the live infrastructure:

```bash
tofu plan
```

The plan should report **no changes**. The `prevent_destroy` lifecycle flag on both resources ensures the instance and elastic IP cannot be destroyed accidentally. Update variables in `variables.tf` if you need to reflect changes to the underlying resources over time.

The security group is now fully managed. SSH is pinned to the WireGuard /24 plus the two emergency home IPs, and the WireGuard UDP listener (51820) is restricted to `var.wireguard_allowed_cidrs` (defaults to the same two IPs). FRP is **disabled by default**—no ports are exposed until you set `enable_frp_access = true` in your vars and re-run `tofu apply`. When that flag is true, the plan adds the FRP control/tunnel rules (7005/7006) scoped to `var.jump_host_port_7005_cidrs` / `var.jump_host_port_7006_cidrs`.

**Admin SSH alias (manual use):** Keep an entry such as `bastion-admin` in your `~/.ssh/config` so you can run privileged commands without remembering the public IP. Example:

```
Host bastion-admin
    HostName 3.82.253.109
    User admin
    IdentityFile ~/.ssh/<your-admin-key>
    IdentitiesOnly yes
```

All manual privileged commands should also run through this alias: `ssh bastion-admin 'sudo ...'`.

## WireGuard server

The configuration now provisions WireGuard directly on the jump host. OpenTofu uploads `scripts/wireguard-bootstrap.sh` before running over SSH as `var.jump_host_admin_user`. The script installs WireGuard, writes `/etc/wireguard/wg0.conf` with `10.99.0.1/24` on port `51820`, enables IP forwarding, and leaves FRP untouched until you explicitly enable it via `enable_frp_access`. Only the CIDRs listed in `var.wireguard_allowed_cidrs` can reach UDP 51820.

| Variable | Purpose | Default |
|----------|---------|---------|
| `wireguard_address` | Address/CIDR assigned to `wg0` | `10.99.0.1/24` |
| `wireguard_listen_port` | UDP port exposed by WireGuard | `51820` |
| `wireguard_peers` | Declarative list of WireGuard peers (public key + allowed IPs) | `[]` |

After `tofu apply` completes, fetch the server public key for client configs:

```bash
ssh bastion-admin 'sudo cat /etc/wireguard/server.pub'
```

Add a `[Peer]` block for each client to `/etc/wireguard/wg0.conf` (or use `wg set`), then restart the service:

```bash
ssh bastion 'sudo systemctl restart wg-quick@wg0'
```

To rerun the provisioning script manually (after editing `aws/scripts/wireguard-bootstrap.sh`), copy it to the host and execute:

```bash
scp aws/scripts/wireguard-bootstrap.sh bastion-admin:~/wireguard-bootstrap.sh
ssh bastion-admin 'sudo chmod +x ~/wireguard-bootstrap.sh && sudo ~/wireguard-bootstrap.sh'
```

### Notes

- To add WireGuard clients through IaC, edit `wireguard_peers` in `terraform.tfvars`. Example:

- The configuration pins values (AMI, subnet, volume settings, etc.) to the current live state so that subsequent changes are explicit. Adjust these variables if you intentionally modify the instance outside of OpenTofu.

### Quick peer setup (macOS)

Run the helper script (it installs `wireguard-tools` if needed, creates keys, updates Terraform vars, and writes a local config under `~/.config/wireguard/`):

```bash
python3 aws/scripts/local-wireguard-setup-on-macos.py
```

You’ll be prompted for a peer name and can accept the suggested `/32` address. The script:

1. Generates a private/public key pair and stores them in `~/.config/wireguard/<peer>.key(.pub)`.
2. Updates `aws/wireguard-peers.auto.tfvars.json` with your public key + IP.
3. Fetches the server public key/endpoint (`bastion-admin` alias required) and writes `~/.config/wireguard/<peer>.conf`.

After it runs:

1. Review/commit the updated `aws/wireguard-peers.auto.tfvars.json`.
2. Apply the change on the jump host:
   ```bash
   cd aws
   tofu apply
   ```
3. Bring the tunnel up locally:
   ```bash
   sudo wg-quick up ~/.config/wireguard/<peer>.conf
   ```

During the helper run you’ll be prompted for “CIDRs to route through WireGuard”.
Keep the default (`10.99.0.0/24`) if you only need access to the VPN subnet.
If you also need to reach other networks (for example the bastion’s private IP
or the Debian host), add them as a comma-separated list such as
`10.99.0.0/24,172.31.82.16/32`.

WireGuard requires elevated privileges to create the tunnel interface on macOS, so `sudo wg-quick` is expected. Use `sudo wg-quick down …` to disconnect.
