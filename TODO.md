# TODO / Implementation Plan

1. **Automate health checks / FRP toggling**
   - Add a lightweight probe (null_resource + `local-exec` or remote command) that fails fast when `ssh bastion-admin` or `ssh debian-vpn` is unreachable, and automatically toggles `enable_frp_emergency` when the check fails.
   - Capture the result somewhere (`terraform output health_check_status`) so it’s obvious whether we’re in FRP mode.

2. **Helper script polish**
   - Auto-generate laptop keys when `refresh_wireguard.py` notices the `.key` file is missing (call `wg genkey` + `wg pubkey`).
   - Have `vpn_health_check.py` optionally emit a short summary line (non-JSON) so it can be used in shell prompts/CI logs.

3. **Secrets management**
   - Move `bastion_wireguard_private_key`, `debian_wireguard_private_key`, and `frp_token` out of the plaintext tfvars file once GSM (or other secret store) is ready.
   - Update the README with the retrieval command (`gcloud secrets versions access ...`) so future operators follow the same process.

4. **Cleanup / consolidation**
   - Remove the legacy `aws/` directory and any unused shell helpers once the new modules have been exercised end-to-end (bastion → Debian → Kubernetes).
   - Replace ad-hoc CIDR lists with data sources or locals once the VPN peer list is finalized (e.g., `jump_host_ssh_cidrs` should reference `wireguard_peers` instead of hard-coded /32s).

5. **Future hygiene tasks**
   - Add a self-test target (e.g., `make verify-vpn`) that runs `ssh -J bastion-admin sysadmin@10.99.0.2 uptime` to confirm WireGuard access before Terraform is invoked.
   - Emit clearer guidance in `README.md` for rotating keys safely (step-by-step for updating tfvars + local configs) so we don’t repeat the “random key regen” issue.
