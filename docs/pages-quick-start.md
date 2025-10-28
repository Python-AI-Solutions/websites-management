# Cloudflare Pages Quick Start

## Add a New Static Site (5 steps)

### 1. Run setup script

```bash
./scripts/setup-new-site.sh PROJECT_NAME SUBDOMAIN "BUILD_COMMAND" "BUILD_DIR"
```

**Example - Quarto site:**
```bash
./scripts/setup-new-site.sh company-handbook handbook "pixi run build" "_site"
```

**Example - Next.js site:**
```bash
./scripts/setup-new-site.sh my-blog blog "npm run build" "out"
```

### 2. Apply Terraform

```bash
pixi run plan-prod    # Review changes
pixi run apply-prod   # Create infrastructure
```

This creates:
- Cloudflare Pages project
- DNS CNAME record
- Custom domain configuration
- HTTPS certificate

### 3. Copy workflow to site repository

```bash
# Copy template
cp .github/workflows/templates/cloudflare-pages-deploy.yml \
   sites/PROJECT_NAME/.github/workflows/deploy.yml

# Edit and customize:
# - PROJECT_NAME
# - BUILD_DIR
# - Build command
# - Framework setup (Pixi or Node.js)
```

### 4. Add GitHub secret

```bash
./scripts/add-github-secret.sh PROJECT_NAME
```

Or manually:
```bash
gh secret set CF_API_TOKEN --repo python-ai-solutions/PROJECT_NAME
```

### 5. Push and deploy

```bash
cd sites/PROJECT_NAME
git add .github/
git commit -m "Add Cloudflare Pages deployment"
git push
```

GitHub Actions will build and deploy automatically.

## Verify Deployment

```bash
# Check DNS
dig SUBDOMAIN.pythonaisolutions.com CNAME +short

# Test HTTPS
curl -I https://SUBDOMAIN.pythonaisolutions.com

# Open in browser
open https://SUBDOMAIN.pythonaisolutions.com
```

## Common Workflows

### Update build configuration

Edit workflow file in site repository:
```yaml
env:
  BUILD_DIR: "new_output_dir"

jobs:
  deploy:
    steps:
      - name: Build site
        run: new build command
```

No Terraform changes needed.

### Add preview deployments

Already included! Every PR gets automatic preview:
- Preview URL: `<branch>.project-name.pages.dev`

### Change custom domain

Edit `envs/prod.tfvars`:
```hcl
pages_projects = {
  "project-name" = {
    custom_domain = "new-subdomain.pythonaisolutions.com"
    # ...
  }
}
```

Apply Terraform:
```bash
pixi run apply-prod
```

### Remove a site

1. Comment out from `envs/prod.tfvars`
2. Run `pixi run apply-prod`
3. Confirm deletion when prompted

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Pages project not found" | Run `pixi run apply-prod` first |
| Custom domain not working | Check DNS: `dig subdomain.pythonaisolutions.com CNAME +short` |
| Build failing | Check GitHub Actions logs in site repository |
| Secret not working | Re-run `./scripts/add-github-secret.sh PROJECT_NAME` |

## Full Documentation

See [cloudflare-pages-iac.md](./cloudflare-pages-iac.md) for:
- Architecture details
- Manual setup steps
- Advanced configuration
- Security best practices
- Migration guide
