# Cloudflare Infrastructure with OpenTofu

This repository manages Cloudflare infrastructure for `pythonaisolutions.com` with OpenTofu, orchestrated by [Pixi](https://pixi.build/). It provides Infrastructure as Code for:

- **DNS zone management** - Migrating from Register365 to Cloudflare
- **Cloudflare Pages projects** - Deploying static sites with automatic HTTPS
- **Google Workspace email** - Maintaining zero downtime for email services

## Quick Start

**New to this repo?**
- DNS migration: See [Migration Guide](docs/migration-guide.md)
- Add a new static site: See [Pages Quick Start](docs/pages-quick-start.md)
- Full Pages documentation: See [Cloudflare Pages IaC](docs/cloudflare-pages-iac.md)

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

## Cloudflare Pages (Static Sites)

This repository manages Cloudflare Pages projects via Infrastructure as Code. All static sites are configured in `envs/prod.tfvars` under `pages_projects`.

### Add a New Site (Quick)

```bash
# Automated setup
./scripts/setup-new-site.sh PROJECT_NAME SUBDOMAIN "BUILD_COMMAND" "BUILD_DIR"

# Example
./scripts/setup-new-site.sh company-handbook handbook "pixi run build" "_site"

# Apply infrastructure
pixi run plan-prod && pixi run apply-prod

# Add GitHub secret
./scripts/add-github-secret.sh PROJECT_NAME

# Copy workflow template to site repository
cp .github/workflows/templates/cloudflare-pages-deploy.yml \
   sites/PROJECT_NAME/.github/workflows/deploy.yml
```

See [Pages Quick Start](docs/pages-quick-start.md) for full instructions.

### Current Sites

| Project | Domain | Status |
|---------|--------|--------|
| hih-presentation | presentations.pythonaisolutions.com | ✅ Configured |
| pythonaisolutions-website | www.pythonaisolutions.com | ✅ Configured |
| company-handbook | handbook.pythonaisolutions.com | ✅ Configured |
| no-strings-resume | resume.pythonaisolutions.com | ✅ Configured |

## CI/CD
GitHub Actions (`.github/workflows/ci.yml`) runs:
- **Plan-only check** on pull requests and manual dispatch.
- Defaults to the `staging` workspace unless you add a `workspace:prod` PR label.
- No automatic apply step runs in GitHub Actions; apply remains a local/manual operator action.

## Next steps
- Verify every placeholder in `envs/prod.tfvars` against the registrar before flipping the nameservers.
- Decide whether you need distinct staging DNS and populate `envs/staging.tfvars`.
- When ready to migrate state to a remote backend (S3/R2), edit the commented block in `root/versions.tf`.
