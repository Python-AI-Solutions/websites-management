# Cloudflare DNS with OpenTofu

This repository manages the Cloudflare DNS zone for `pythonaisolutions.com` with OpenTofu, orchestrated by [Pixi](https://pixi.build/). It provides Infrastructure as Code for migrating from Register365 to Cloudflare while maintaining zero downtime for Google Workspace email.

## Quick Start

**New to this repo?** See the [Migration Guide](docs/migration-guide.md) for step-by-step instructions on migrating from Register365 to Cloudflare.

## Prerequisites
- [OpenTofu](https://opentofu.org/) 1.7.0+ (installed via Homebrew: `brew install opentofu`)
- [Pixi](https://prefix.dev/docs/pixi/) (install via `curl -fsSL https://pixi.sh/install.sh | bash`)
- A Cloudflare API token with **Zone:DNS:Edit** permissions on `pythonaisolutions.com`
- Cloudflare account ID (get it via `bash scripts/get-account-id.sh`)

## One-time setup
1. Copy `.env.example` to `.env` and populate your secrets:
   ```bash
   cp .env.example .env
   ```
   At minimum set `CLOUDFLARE_API_TOKEN`. You can also pre-set DMARC/SPF defaults here.
2. Review the current DNS entries in `envs/prod.tfvars` and replace every `TODO` placeholder with the authoritative values (see notes below).
3. If you maintain a separate staging footprint, update `envs/staging.tfvars` accordingly. It defaults to the production values so you can quickly clone records.

## Working with OpenTofu

Common Pixi tasks:

```bash
# Initialize OpenTofu
pixi run init

# Work with workspaces
pixi run workspace-staging    # create/select the staging workspace
pixi run workspace-prod       # create/select the prod workspace

# Plan changes
pixi run plan-staging         # writes root/tfplan-staging.tfplan
pixi run plan-prod           # writes root/tfplan-prod.tfplan

# Apply changes
pixi run apply-staging       # apply staging changes
pixi run apply-prod          # apply prod changes

# Verify DNS after migration
pixi run verify-dns          # check DNS records and website accessibility

# Code quality
pixi run fmt                 # format all .tf files
pixi run validate            # validate configuration
pixi run lint                # run tflint
```

The same tasks power CI workflows, so local and GitHub Actions runs stay identical.

## Managing DNS data
DNS records live in two variables:
- `apex_records` – A/AAAA/TXT/CAA/SRV definitions for the zone apex (`@`).
- `subdomain_records` – Per-subdomain bundles (A, CNAME, NS, TXT, MX, SRV) keyed by relative hostname.

**Before migration**, update these placeholders in `envs/prod.tfvars`:
- `google-site-verification=TODO_replace_with_token` – Get from Google Search Console
- GitHub Pages challenge records will need to be regenerated after migration (see [Migration Guide](docs/migration-guide.md))

**After migrating to Cloudflare**, GitHub will provide new challenge values when you re-add custom domains.

## Google Workspace
The `google-workspace-email` module provisions:
- MX records for Gmail
- SPF TXT (`v=spf1 include:_spf.google.com ~all` by default)
- DMARC TXT at `_dmarc`
- Optional Google site verification TXT
- DKIM placeholders (update once Google issues active selectors)

See `docs/google-workspace-setup.md` for the detailed checklist, including how to supply DKIM values after you migrate.

## CI/CD
GitHub Actions (`.github/workflows/ci.yml`) runs:
- **Plan** on pull requests – defaults to the `staging` workspace unless you add a `workspace:prod` label, and uploads plan artifacts.
- **Apply** on pushes to `main` – runs against the `prod` workspace under the protected `prod` environment, requiring manual approval before touching live DNS.

## Next steps
- Verify every placeholder in `envs/prod.tfvars` against the registrar before flipping the nameservers.
- Decide whether you need distinct staging DNS and populate `envs/staging.tfvars`.
- When ready to migrate state to a remote backend (S3/R2), edit the commented block in `root/versions.tf`.
