# Documentation Index

Use this index to distinguish the current production DNS/static-site work from migration history and paused Kubernetes notes.

## Current Production Operations

### [Cloudflare Pages Quick Start](pages-quick-start.md)
Short workflow for adding or updating a static site on Cloudflare Pages.

### [Cloudflare Pages Infrastructure as Code](cloudflare-pages-iac.md)
Architecture and operational guide for managing Pages projects, DNS records, custom domains, and certificates from OpenTofu.

### [DNS Records Reference](dns-records-reference.md)
Technical reference for the DNS record structures used by `envs/prod.tfvars`.

### [Google Workspace DNS Checklist](google-workspace-setup.md)
Checklist for Google Workspace MX, SPF, DMARC, DKIM, and site verification records.

### [Cloudflare API Token Setup](cloudflare-api-token-setup.md)
Permissions and local environment setup for Cloudflare DNS and Pages operations.

### [Google Site Verification Guide](google-site-verification-guide.md)
DNS-first verification flow for Google Search Console and related Google services.

## Migration History and Reference

### [Migration Guide](migration-guide.md)
Historical Register365-to-Cloudflare migration guide. Useful for understanding the original cutover sequence, not the current steady state.

### [Migration Checklist](migration-checklist.md)
Historical day-of migration checklist.

### [DNS Records Review](dns-records-review.md)
Review notes from the DNS cleanup and migration planning phase.

### [Removed DNS Records](removed-dns-records.md)
Archive of records removed during cleanup.

### [Migrating Static Sites to Cloudflare Pages](migrate-sites-to-cloudflare-pages.md)
Reference guide for the static-site migration pattern now used by this repo.

## Paused Kubernetes Work

### [Kubernetes Setup Prompt](prompt-for-k8s-setup.md)
Planning prompt for a future single-node Kubernetes redeploy.

### [Kubernetes Redeploy Risk Notes](k8s-redeploy-risk-notes.md)
Non-invasive review notes for bastion, WireGuard, FRP, kubeconfig handling, and audit logging before the next redeploy.

Kubernetes, bastion, WireGuard, ingress, and security-hardening materials are retained for future work. They are not the current production operating surface for the public sites.

## Common Commands

```bash
pixi run fmt
pixi run validate
pixi run plan-prod
pixi run verify-dns
```

`plan-prod` and apply commands require Cloudflare credentials. Use `verify-dns` after DNS or custom-domain changes.
