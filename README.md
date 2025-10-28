# Cloudflare DNS with OpenTofu

This repository manages the Cloudflare DNS zone for `pythonaisolutions.com` with OpenTofu, using a Dockerised toolchain orchestrated by [Pixi](https://pixi.build/). It captures the current registrar records (see `envs/prod.tfvars`) so you can migrate the domain into Cloudflare with confidence, while keeping Google Workspace email healthy.

## Prerequisites
- Docker Desktop or Docker Engine 24+
- [Pixi](https://prefix.dev/docs/pixi/) (install via `curl -fsSL https://pixi.sh/install.sh | bash`)
- A Cloudflare API token with **Zone:DNS:Edit** permissions on `pythonaisolutions.com`
- (Optional) Cloudflare account ID, if the API token needs explicit scoping

## One-time setup
1. Copy `.env.example` to `.env` and populate your secrets:
   ```bash
   cp .env.example .env
   ```
   At minimum set `CLOUDFLARE_API_TOKEN`. You can also pre-set DMARC/SPF defaults here.
2. Review the current DNS entries in `envs/prod.tfvars` and replace every `TODO` placeholder with the authoritative values (see notes below).
3. If you maintain a separate staging footprint, update `envs/staging.tfvars` accordingly. It defaults to the production values so you can quickly clone records.

## Working with OpenTofu
All Terraform/OpenTofu commands run inside the Docker container via Pixi tasks:

```bash
pixi run init            # tofu init inside the container
pixi run ws:staging      # create/select the staging workspace
pixi run plan:staging    # writes root/tfplan-staging.tfplan
scripts/tofu.sh show -no-color tfplan-staging.tfplan   # inspect the plan
pixi run apply:staging   # apply staging changes (auto-approve)
pixi run ws:prod
pixi run plan:prod
pixi run apply:prod
```

The same tasks power CI workflows, so local and GitHub Actions runs stay identical. Use `pixi run pre-commit:install` once to wire up the formatting/lint hooks, and `pixi run pre-commit:run` to check the full tree.

## Managing DNS data
DNS records live in two variables:
- `apex_records` – A/AAAA/TXT/CAA/SRV definitions for the zone apex (`@`).
- `subdomain_records` – Per-subdomain bundles (A, CNAME, NS, TXT, MX, SRV) keyed by relative hostname.

Notable placeholders you must update in `envs/prod.tfvars` before cutover:
- `google-site-verification=...` and `MS=...` TXT strings – copy from the registrar UI.
- `autodiscover.TODO-update` SRV target – supply the exact host you use today.
- `autoconfig.TODO-complete`, `hih-presentation.TODO-update`, and the `_github-pages-challenge-*` TXT entries – replace with the precise targets/tokens.
- Rename `_github-pages-challenge-1` / `-2` keys to the real record names (e.g. `_github-pages-challenge-leej3.pythonaisolutions.com`) once you have the full strings.

Staging inherits the same structure. Populate it with staging-specific IPs or CNAMEs when you spin up parallel infrastructure.

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
