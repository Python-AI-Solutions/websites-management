# Cloudflare Pages Infrastructure as Code

This guide explains how to manage Cloudflare Pages projects using Infrastructure as Code (IaC) with OpenTofu/Terraform.

## Overview

All Cloudflare Pages projects are managed via Terraform in this repository. The infrastructure handles:

- **Pages project creation** - Creating the Cloudflare Pages project in your account
- **DNS configuration** - CNAME records pointing custom domains to pages.dev URLs
- **Custom domain setup** - Configuring custom domains in the Pages project
- **HTTPS certificates** - Automatic SSL/TLS certificate provisioning

Site repositories only need a simple GitHub Actions workflow to build and deploy - all infrastructure is managed centrally.

## Architecture

```
cloudflare-management/                    # IaC repository (this repo)
├── modules/cloudflare-pages/            # Terraform module for Pages
├── envs/prod.tfvars                     # Pages project configurations
└── scripts/
    ├── setup-new-site.sh                # Automated site setup
    └── add-github-secret.sh             # Add CF_API_TOKEN to repos

sites/your-site/                          # Site repository (submodule)
└── .github/workflows/deploy.yml         # Simple build + deploy workflow
```

## Benefits of IaC Approach

### Centralized Management
- All Pages projects defined in one place (`envs/prod.tfvars`)
- Consistent DNS and domain configuration
- Easy to see all deployed sites at a glance

### Reproducible
- Add new sites by copying configuration block
- Template-based workflow setup
- Scripted secret management

### Version Controlled
- Infrastructure changes tracked in git
- Review process via pull requests
- Rollback capability

### Minimal Per-Site Configuration
- Site repos only need workflow file
- No manual Cloudflare dashboard clicking
- Reduced human error

## Adding a New Site

### Option 1: Automated Script (Recommended)

```bash
./scripts/setup-new-site.sh PROJECT_NAME SUBDOMAIN BUILD_COMMAND BUILD_DIR

# Example for a Quarto site:
./scripts/setup-new-site.sh company-handbook handbook "pixi run build" "_site"

# Example for a Next.js site:
./scripts/setup-new-site.sh my-app app "npm run build" "out"
```

This script will:
1. Add configuration to `envs/prod.tfvars`
2. Show next steps for Terraform apply
3. Provide instructions for workflow setup

### Option 2: Manual Configuration

1. **Add to `envs/prod.tfvars`**:

```hcl
pages_projects = {
  # ... existing projects ...

  "your-project-name" = {
    production_branch = "main"
    build_command     = "npm run build"  # or "pixi run build"
    destination_dir   = "out"            # or "_site", "dist", etc.
    custom_domain     = "subdomain.pythonaisolutions.com"
    dns_ttl           = 3600
    dns_proxied       = false
  }
}
```

2. **Apply Terraform**:

```bash
pixi run plan-prod   # Review changes
pixi run apply-prod  # Create infrastructure
```

3. **Copy workflow template** to site repository:

```bash
mkdir -p sites/your-project/.github/workflows
cp .github/workflows/templates/cloudflare-pages-deploy.yml \
   sites/your-project/.github/workflows/deploy.yml
```

4. **Customize workflow** - Edit `deploy.yml`:
   - Set `PROJECT_NAME` to match Terraform config
   - Set `BUILD_DIR` to match destination_dir
   - Update build command
   - Enable appropriate setup (Pixi or Node.js)

5. **Add GitHub secret**:

```bash
./scripts/add-github-secret.sh your-project-name

# Or manually:
# gh secret set CF_API_TOKEN --repo python-ai-solutions/your-project
```

6. **Push and deploy**:

```bash
cd sites/your-project
git add .github/
git commit -m "Add Cloudflare Pages deployment"
git push
```

## Workflow Template Customization

The template at `.github/workflows/templates/cloudflare-pages-deploy.yml` supports:

### Framework Options

**Pixi (Quarto, Python-based):**
```yaml
- name: Install Pixi
  uses: prefix-dev/setup-pixi@v0.8.1
- run: pixi install
- run: pixi run build
```

**Node.js (Next.js, React, etc.):**
```yaml
- name: Setup Node
  uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'
- run: npm install
- run: npm run build
```

### Optional Steps

**Pre-commit hooks:**
```yaml
- name: Run pre-commit hooks
  run: pixi run hooks  # or: npm run lint
```

**Tests:**
```yaml
- name: Run tests
  run: pixi run test  # or: npm test
```

**Copy additional files:**
```yaml
- name: Copy routing config
  run: cp routes/_routes.json ${{ env.BUILD_DIR }}/
```

### Required Configuration

Every workflow needs:
- `PROJECT_NAME`: Must match the key in `pages_projects` in Terraform
- `BUILD_DIR`: Must match `destination_dir` in Terraform
- `CF_API_TOKEN`: GitHub secret (same token used for Terraform)

## DNS and Custom Domains

The Terraform module automatically:

1. **Creates CNAME record**: `subdomain.pythonaisolutions.com` → `project-name.pages.dev`
2. **Configures custom domain** in Pages project
3. **Provisions HTTPS certificate** (automatic via Cloudflare)

After `pixi run apply-prod`, the custom domain is immediately available.

## Deployment Flow

```
┌─────────────────────┐
│ Developer pushes    │
│ to site repository  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ GitHub Actions      │
│ - Install deps      │
│ - Run tests         │
│ - Build site        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Wrangler CLI        │
│ pages deploy        │
│ (using CF_API_TOKEN)│
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Cloudflare Pages    │
│ (already created    │
│  via Terraform)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Site live at:       │
│ project.pages.dev   │
│ custom.domain.com   │
└─────────────────────┘
```

## Preview Deployments

The workflow automatically creates preview deployments for pull requests:

- **PR Preview**: `<branch>.project-name.pages.dev`
- **Production**: `project-name.pages.dev` and custom domain

Each PR gets its own isolated preview environment.

## Managing Multiple Sites

Current sites (as of setup):

| Project | Custom Domain | Framework | Status |
|---------|---------------|-----------|--------|
| hih-presentation | presentations.pythonaisolutions.com | Quarto | ✅ Configured |
| pythonaisolutions_website | www.pythonaisolutions.com | Next.js | 🟡 Planned |
| company-handbook | handbook.pythonaisolutions.com | Quarto | 🟡 Planned |
| no-strings-resume | TBD | Next.js | 🟡 Planned |

To add more:
1. Add to `pages_projects` in `envs/prod.tfvars`
2. Run `pixi run apply-prod`
3. Copy workflow template to site repo
4. Add `CF_API_TOKEN` secret
5. Push to deploy

## Terraform Module Reference

### Module: cloudflare-pages

**Location**: `modules/cloudflare-pages/`

**Resources Created**:
- `cloudflare_pages_project` - Pages project in Cloudflare account
- `cloudflare_pages_domain` - Custom domain configuration
- `cloudflare_record` - DNS CNAME record

**Inputs**:
```hcl
variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "project_name" {
  description = "Name of the Pages project"
  type        = string
}

variable "production_branch" {
  description = "Git branch for production"
  type        = string
  default     = "main"
}

variable "build_command" {
  description = "Build command (informational, not used by Direct Upload)"
  type        = string
  default     = ""
}

variable "destination_dir" {
  description = "Output directory (informational)"
  type        = string
  default     = ""
}

variable "custom_domain" {
  description = "Custom domain (e.g., subdomain.example.com)"
  type        = string
  default     = ""
}

variable "zone_id" {
  description = "Cloudflare zone ID"
  type        = string
  default     = ""
}

variable "zone_name" {
  description = "Zone name for subdomain calculation"
  type        = string
  default     = ""
}
```

**Outputs**:
```hcl
output "project_id" {
  description = "Pages project ID"
  value       = cloudflare_pages_project.this.id
}

output "pages_dev_url" {
  description = "Default pages.dev URL"
  value       = "${project_name}.pages.dev"
}

output "custom_domain" {
  description = "Configured custom domain"
  value       = var.custom_domain
}
```

## Troubleshooting

### "Pages project not found" during deployment

The Terraform must be applied before the GitHub workflow can deploy:

```bash
pixi run apply-prod
```

Wait 1-2 minutes for project creation, then retry deployment.

### Custom domain activation failed

Ensure Terraform was applied successfully:

```bash
pixi run plan-prod  # Should show no changes if applied
```

Check DNS propagation:

```bash
dig subdomain.pythonaisolutions.com CNAME +short
# Should show: project-name.pages.dev
```

### GitHub secret not working

Verify secret is set:

```bash
gh secret list --repo python-ai-solutions/your-project
```

Re-add if missing:

```bash
./scripts/add-github-secret.sh your-project
```

### Build command differs from Terraform

The `build_command` in Terraform is **informational only** for Direct Upload deployments. The actual build happens in GitHub Actions using the workflow file.

To change build command:
1. Edit workflow file in site repository
2. No Terraform changes needed

### Removing a Site

1. **Remove from Terraform**:

```hcl
# Comment out or delete from envs/prod.tfvars
pages_projects = {
  # "old-project" = { ... }  # Removed
}
```

2. **Apply Terraform**:

```bash
pixi run plan-prod   # Review deletion
pixi run apply-prod  # Confirm to delete
```

This will:
- Delete the Pages project
- Remove DNS CNAME record
- Remove custom domain configuration

3. **Clean up site repository** (optional):
- Delete `.github/workflows/deploy.yml`
- Remove `CF_API_TOKEN` secret

## Security Best Practices

### API Token Permissions

The `CF_API_TOKEN` needs minimal permissions:

**Required**:
- Account | Cloudflare Pages | Edit

**Not Required**:
- Zone | DNS | Edit (Terraform handles DNS)
- Other permissions

Create token at: https://dash.cloudflare.com/profile/api-tokens

### Token Rotation

When rotating the API token:

1. **Create new token** in Cloudflare dashboard
2. **Update `.env` file** in cloudflare-management repo
3. **Update GitHub secrets** for all site repositories:

```bash
for repo in hih-presentation company-handbook pythonaisolutions_website; do
  ./scripts/add-github-secret.sh $repo
done
```

4. **Test deployment** in one site before updating all

### Least Privilege

- Use **separate tokens** for Terraform (zone management) and deployments (Pages only)
- Store tokens as GitHub secrets, not in code
- Rotate tokens periodically

## Advanced Configuration

### Environment Variables

Add build-time environment variables:

```hcl
pages_projects = {
  "my-app" = {
    # ... basic config ...
    production_env_vars = {
      NODE_ENV = "production"
      API_URL  = "https://api.example.com"
    }
    preview_env_vars = {
      NODE_ENV = "preview"
      API_URL  = "https://staging-api.example.com"
    }
  }
}
```

### Multiple Domains

To add multiple domains for one project:

```hcl
# In Terraform, configure primary domain
pages_projects = {
  "my-app" = {
    custom_domain = "app.pythonaisolutions.com"
    # ...
  }
}

# Additional domains: add manually in Cloudflare dashboard
# or create additional cloudflare_pages_domain resources
```

### Custom Branch Deployments

To deploy branches other than main:

```yaml
# In workflow file
on:
  push:
    branches: ["main", "staging"]  # Add staging branch

env:
  BRANCH_NAME: ${{ github.ref_name }}

# Update deploy command:
command: pages deploy ... --branch ${{ env.BRANCH_NAME }}
```

## Migration from Manual Setup

If you have existing Pages projects created manually:

1. **Import into Terraform**:

```bash
cd root
tofu import 'module.pages_projects["project-name"].cloudflare_pages_project.this' \
  ACCOUNT_ID/PROJECT_NAME
```

2. **Add configuration** to `envs/prod.tfvars`

3. **Run plan** to verify no changes:

```bash
pixi run plan-prod
# Should show "No changes" if configuration matches
```

4. **Update workflow** in site repository to use Wrangler CLI

## Resources

- [Cloudflare Pages Docs](https://developers.cloudflare.com/pages/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)
- [Direct Upload](https://developers.cloudflare.com/pages/platform/direct-upload/)
- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)

## Support

For issues with:
- **Infrastructure/Terraform**: Open issue in cloudflare-management repo
- **Site deployments**: Check GitHub Actions logs in site repository
- **Cloudflare**: Check Cloudflare dashboard or support
