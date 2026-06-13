# Sites Inventory

This directory contains site repositories tracked from the parent `websites-management` repo. The current tracked sites are Git submodules pinned by the parent repo; do not replace those pins with state from another local checkout.

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
