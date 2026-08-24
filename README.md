# Websites Management

This repository is the public infrastructure companion for the Python AI Solutions web properties.

The current production responsibility here is Cloudflare-managed DNS, Cloudflare Pages configuration, Google Workspace DNS records, and static-site domain routing. Kubernetes and bastion/VPN material is retained in the repo, but it is paused and redeploy-pending; it should not be read as a claim that the Kubernetes platform is currently production-hardened.

## Status at a Glance

| Area | Current state | Source of truth |
| --- | --- | --- |
| Primary DNS for `pythonaisolutions.com` | Production-managed in Cloudflare | `root/`, `modules/cloudflare-*`, `envs/prod.tfvars` |
| Static web hosting | Production Cloudflare Pages projects and custom domains | `pages_projects` in `envs/prod.tfvars` |
| Google Workspace DNS | Production-managed when `gmail_enabled = true` | `modules/google-workspace-email`, `envs/prod.tfvars` |
| Additional web domains | Production Cloudflare zones and Pages aliases | `additional_zones`, `additional_pages_domains` in `envs/prod.tfvars` |
| Kubernetes / bastion / WireGuard | Paused; redeploy and hardening review still required | `k8s/`, `docs/prompt-for-k8s-setup.md`, `docs/k8s-redeploy-risk-notes.md` |

## For Portfolio Visitors

If you arrived from the Infrastructure portfolio page, read this repository as a snapshot of real domain and static-site operations plus work-in-progress platform notes.

What is production today:

- Cloudflare DNS zone management for `pythonaisolutions.com`.
- Cloudflare Pages projects for the public static sites and app front ends.
- Custom domain mappings for Pages, including apex and `www` routing.
- Google Workspace email DNS records and site verification records.
- Additional Cloudflare-managed domains for the no-strings resume property.

What is not being claimed yet:

- A currently active production Kubernetes platform.
- Completed Kubernetes security hardening.
- Current GitOps, ingress, VPN, or cluster operations beyond retained planning and redeploy notes.

## Repository Map

- `root/` - OpenTofu root module for Cloudflare zones, DNS records, Pages projects, and Google Workspace DNS.
- `modules/` - Reusable OpenTofu modules for Cloudflare DNS, Pages, zones, and Google Workspace email records.
- `envs/prod.tfvars` - Production configuration for domains, Pages projects, and DNS records.
- `docs/` - Public documentation, migration notes, and operating guides.
- `k8s/` - Paused Kubernetes and bastion/VPN infrastructure work retained for future redeploy.
- `sites/` - Site repository submodule pointers. Submodules may not be initialized in every clone.

## Start Here

- [Documentation index](docs/README.md)
- [Cloudflare Pages quick start](docs/pages-quick-start.md)
- [Cloudflare Pages IaC guide](docs/cloudflare-pages-iac.md)
- [Cloudflare state recovery](docs/cloudflare-state-recovery.md)
- [DNS records reference](docs/dns-records-reference.md)
- [Google Workspace DNS checklist](docs/google-workspace-setup.md)

## Local Commands

```bash
pixi run fmt
pixi run validate
pixi run plan-prod
pixi run verify-dns
```

`plan-prod` and apply commands require the appropriate Cloudflare credentials in the local environment.
