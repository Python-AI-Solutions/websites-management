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

The security group is now fully managed (including the new TCP 7005 rule). Adjust the allowed CIDRs through `var.jump_host_ssh_cidrs` and `var.jump_host_port_7005_cidrs` if you need to restrict access. AWS security groups only allow ~60 unique CIDR entries, so the WireGuard UDP rule stays open (`0.0.0.0/0`) and the host-level script applies the India/Ireland restriction via `ipset`/iptables (described below).

## WireGuard server

The configuration now provisions WireGuard directly on the jump host. OpenTofu uploads `scripts/wireguard-bootstrap.sh` (a plain Bash script with the chosen defaults) and executes it over SSH using `var.jump_host_admin_user`. The script installs WireGuard, writes `/etc/wireguard/wg0.conf` with `10.99.0.1/24` on port `51820`, enables IP forwarding, downloads the India + Ireland IP ranges from [ipdeny.com](https://www.ipdeny.com), loads them into an `ipset`, and inserts iptables rules so that ports 51820/7005/7006 only accept packets from those countries. Customize these inputs to match your environment (or rerun the script manually after editing it):

| Variable | Purpose | Default |
|----------|---------|---------|
| `wireguard_address` | Address/CIDR assigned to `wg0` | `10.99.0.1/24` |
| `wireguard_listen_port` | UDP port exposed by WireGuard | `51820` |

After `tofu apply` completes, fetch the server public key for client configs:

```bash
ssh newuser@$(tofu output -raw jump_host_public_ip) 'sudo cat /etc/wireguard/server.pub'
```

Add a `[Peer]` block for each client to `/etc/wireguard/wg0.conf` (or use `wg set`), then restart the service:

```bash
ssh newuser@<jump-host> 'sudo systemctl restart wg-quick@wg0'
```

To rerun the provisioning script manually (after editing `scripts/wireguard-bootstrap.sh`), copy it to the host and execute:

```bash
scp scripts/wireguard-bootstrap.sh newuser@<jump-host>:/tmp/wireguard-bootstrap.sh
ssh newuser@<jump-host> 'sudo chmod +x /tmp/wireguard-bootstrap.sh && sudo /tmp/wireguard-bootstrap.sh'
```

### Notes

- The configuration pins values (AMI, subnet, volume settings, etc.) to the current live state so that subsequent changes are explicit. Adjust these variables if you intentionally modify the instance outside of OpenTofu.
