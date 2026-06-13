# Sites Inventory

This directory contains site repositories tracked from the parent `websites-management` repo. The current tracked sites are Git submodules pinned by the parent repo; do not replace those pins with state from another local checkout.

## Tracked Site Repositories

| Site path | Repository | Production inventory |
| --- | --- | --- |
| `sites/agentic-cervical-screener` | `git@github.com:Python-AI-Solutions/agentic-cervical-screener.git` | Cloudflare Pages: `cervical-screening.pythonaisolutions.com` |
| `sites/company-handbook` | `git@github.com:Python-AI-Solutions/company-handbook.git` | Cloudflare Pages: `handbook.pythonaisolutions.com` |
| `sites/consistency-tracker` | `git@github.com:leej3/consistency-tracker.git` | Cloudflare Pages project without a custom domain in `envs/prod.tfvars` |
| `sites/entra-validation-app` | `git@github.com:Python-AI-Solutions/entra-validation-app.git` | Cloudflare Pages: `entra-auth.pythonaisolutions.com` |
| `sites/food-tracker` | `git@github.com:leej3/food-tracker.git` | Cloudflare Pages: `food-tracker-7qq.pages.dev`; not managed in `envs/prod.tfvars` |
| `sites/hih-presentation` | `git@github.com:python-ai-solutions/hih-presentation.git` | Cloudflare Pages: `presentations.pythonaisolutions.com` |
| `sites/migration-computation` | `git@github.com:leej3/migration-computation.git` | Tracked repo; no Cloudflare Pages project in `envs/prod.tfvars` |
| `sites/no-strings-resume` | `git@github.com:NoStringsDevelopment/no-strings-resume.git` | Cloudflare Pages: `resume.pythonaisolutions.com`, `nostringsresume.com`, `www.nostringsresume.com`, `nostringsresume.org`, `www.nostringsresume.org` |
| `sites/operandi` | `git@github.com:Python-AI-Solutions/operandi.git` | Tracked repo; no Cloudflare Pages project in `envs/prod.tfvars` |
| `sites/pythonaisolutions_website` | `git@github.com:Python-AI-Solutions/pythonaisolutions_website.git` | Cloudflare Pages: `pythonaisolutions.com`, `www.pythonaisolutions.com` |

## Pending Site Repositories

| Site | Status | Next parent-repo action |
| --- | --- | --- |
| Recharged model comparison app | `tesla-used-evaluator` evolved into a generic comparison app that scraped `recharged.com`; `recharged.com` itself is external. No app remote repo URL is recorded here yet. | Deferred for this pass. See [Recharged model comparison](../docs/websites/recharged-model-comparison.md). |

## Quick Analysis

Run `pixi run analyze-sites` to see deployment configuration details for all sites.

## Purpose

Tracking the site repos here allows:
- Centralized DNS management for all sites
- Easy verification that DNS records match deployment targets
- Unified view of all properties when planning migrations
- Version control of which site versions are deployed

## Managing Submodules

### Clean Checkout Rule

Use `.gitmodules` and the parent gitlinks as the source of truth. Avoid adding submodules from local paths or copying site state from another checkout, because that can pull stale local-main changes into this parent repo.

### Initial Clone
When cloning this repository, initialize all submodules:
```bash
git clone git@github.com:Python-AI-Solutions/websites-management.git
cd websites-management
git submodule update --init --recursive
```

### Update All Submodules
```bash
git submodule update --remote --merge
```

### Update Specific Submodule
```bash
cd sites/site-name
git pull origin main
cd ../..
git add sites/site-name
git commit -m "Update site-name to latest"
```

### Check Submodule Status
```bash
git submodule status
```

## Next Steps

1. Run `pixi run analyze-sites` to see detailed deployment information
2. Update DNS records in `envs/prod.tfvars` to match actual deployments
3. Document deployment details for each site
4. Plan migration strategy for sites moving to Cloudflare
