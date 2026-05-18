# Sites Inventory

This directory contains site repositories tracked from the parent `websites-management` repo. Most are Git submodules, and newer additions should follow the same pattern.

## Tracked Site Repositories

The current inventory is:

1. `agentic-cervical-screener`
2. `company-handbook`
3. `consistency-tracker`
4. `entra-validation-app`
5. `hih-presentation`
6. `migration-computation`
7. `no-strings-resume`
8. `operandi`
9. `pythonaisolutions_website`

## Quick Analysis

Run `pixi run analyze-sites` to see deployment configuration details for all sites.

## Purpose

Tracking the site repos here allows:
- Centralized DNS management for all sites
- Easy verification that DNS records match deployment targets
- Unified view of all properties when planning migrations
- Version control of which site versions are deployed

## Managing Submodules

### Initial Clone
When cloning this repository, initialize all submodules:
```bash
git clone git@github.com:YOUR-ORG/cloudflare-management.git
cd cloudflare-management
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
