# Kubernetes Redeploy Risk Notes

These notes are for the next Kubernetes/bastion review. They are not deployment instructions, and this tidy-up branch does not change the `k8s/` OpenTofu modules.

## Current Context

- The Kubernetes node is not currently up.
- The bastion is a pre-existing AWS instance.
- The intended current access pattern is SSH public-key authentication from arbitrary developer IPs, because developer IPs may be unstable.
- FRP should remain available as emergency plumbing, but not treated as the normal access path.
- Pull request #5 (`open-source`) is stale/conflicting and should be used only as review material, not merged as-is.

## Items To Review Before Redeploy

1. **SSH exposure on bastion**
   The current model allows SSH from broad source ranges and relies on public-key auth. That can be acceptable for developer ergonomics, but before redeploy verify password auth is disabled, root login is disabled, Fail2ban or equivalent rate limiting is active, and AWS security group intent matches the documented access pattern.

2. **FRP exposure and token handling**
   FRP should stay, but confirm it is disabled unless emergency access is intentionally needed. If enabled, verify the public ports, token strength, and whether FRP should be source-restricted or protected by an additional network control.

3. **WireGuard peer inventory**
   WireGuard peer public keys and allowed IPs can be tracked as shared deployment metadata. Private keys, preshared keys, generated client configs, and live kubeconfigs should not be tracked.

4. **Kubeconfig handling**
   The current module copies `/etc/kubernetes/admin.conf` through `/tmp/kubeconfig` and fetches it with relaxed SSH host-key checks. Before redeploy, review whether this should stream directly over SSH, keep local permissions at `0600`, and use normal known-host verification.

5. **Kubernetes audit policy**
   The current audit policy logs Secret access at `RequestResponse` level. Before redeploy, confirm whether Secret request/response bodies should be excluded from audit logs to avoid writing secret values into log files.

6. **Terraform/OpenTofu local artifacts**
   State files, plans, kubeconfigs, `.dev.vars`, local env files, private keys, and generated client configs should remain ignored and blocked by guardrails.
