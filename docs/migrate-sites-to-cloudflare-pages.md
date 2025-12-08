# Migrating Static Sites to Cloudflare Pages

This guide covers migrating your static sites from various platforms (GitHub Pages, etc.) to Cloudflare Pages.

## Sites Overview

Based on the analysis, here are the sites and their recommended migration paths:

| Site | Current Platform | Type | Migration Complexity | Recommended Action |
|------|------------------|------|---------------------|-------------------|
| hih-presentation | Cloudflare Pages | Quarto/Static | ✅ Complete | Monitor via Pages workflow |
| pythonaisolutions_website | Cloudflare Pages | Next.js (Static export) | ✅ Complete | Maintain via Pages workflow |
| company-handbook | Cloudflare Pages | Quarto/Static | ✅ Complete | Maintain via Pages workflow |
| no-strings-resume | Cloudflare Pages | React/Vite | ✅ Complete | Monitor via Pages workflow |

## Why Migrate to Cloudflare Pages?

### Benefits:
- ✅ **Unified platform**: DNS and hosting in one place
- ✅ **Better performance**: Cloudflare's global CDN
- ✅ **Built-in security**: DDoS protection, WAF
- ✅ **Unlimited bandwidth**: No GitHub Pages limits
- ✅ **Preview deployments**: Automatic PR previews
- ✅ **Custom headers/redirects**: More control
- ✅ **Analytics**: Built-in web analytics

### When to Keep GitHub Pages:
- ❌ Already working perfectly and no issues
- ❌ Don't need advanced features
- ❌ Want to keep things simple

## General Migration Process

### Prerequisites
1. Site builds successfully locally
2. GitHub Actions or build process defined
3. Cloudflare account with DNS access
4. Cloudflare API token with Pages permissions

### Step 1: Prepare Repository

#### For Static Sites (Quarto, Hugo, Jekyll, etc.)

1. **Identify build command and output directory**
   ```bash
   # Common examples:
   # Quarto: pixi run build → _site/
   # Hugo: hugo → public/
   # Jekyll: jekyll build → _site/
   ```

2. **Test build locally**
   ```bash
   # Make sure build succeeds
   pixi run build  # or your build command
   ls _site/       # verify output exists
   ```

3. **Create `_routes.json` (optional)**
   ```bash
   mkdir -p routes
   cat > routes/_routes.json << 'EOF'
   {
     "version": 1,
     "include": ["/*"],
     "exclude": []
   }
   EOF
   ```

#### For Framework Sites (Next.js, Nuxt, etc.)

1. **Check if framework is supported**
   - See: https://developers.cloudflare.com/pages/framework-guides/

2. **Review build configuration**
   - Next.js: Verify `next.config.js` for `output: 'export'` if using static export
   - Or keep SSR and use Pages Functions

3. **Test build**
   ```bash
   npm run build
   # Verify output directory (usually `out/` or `.next/`)
   ```

### Step 2: Create Cloudflare Pages Project

#### Option A: Direct Upload (Wrangler CLI - Recommended)

**Advantages:**
- More control over deployment
- Works with any CI/CD
- Can deploy from monorepos
- Better for complex setups

**Setup:**

1. **Create GitHub Actions workflow**
   ```yaml
   # .github/workflows/deploy.yml
   name: Deploy to Cloudflare Pages

   on:
     push:
       branches: ["main"]
     pull_request:
       branches: ["main"]

   permissions:
     contents: read
     deployments: write

   env:
     PROJECT_NAME: your-project-name
     BUILD_DIR: _site  # or your output directory

   jobs:
     deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4

         - name: Setup Node (if needed)
           uses: actions/setup-node@v4
           with:
             node-version: '20'

         # Or for Pixi-based projects:
         - name: Install Pixi
           uses: prefix-dev/setup-pixi@v0.8.1

         - name: Install dependencies
           run: npm install  # or: pixi install

         - name: Build
           run: npm run build  # or: pixi run build

         - name: Deploy preview
           if: github.event_name == 'pull_request'
           uses: cloudflare/wrangler-action@v3
           with:
             apiToken: ${{ secrets.CF_API_TOKEN }}
             wranglerVersion: '3'
             command: pages deploy ./${{ env.BUILD_DIR }} --project-name ${{ env.PROJECT_NAME }} --branch ${{ github.head_ref }}

         - name: Deploy production
           if: github.event_name == 'push'
           uses: cloudflare/wrangler-action@v3
           with:
             apiToken: ${{ secrets.CF_API_TOKEN }}
             wranglerVersion: '3'
             command: pages deploy ./${{ env.BUILD_DIR }} --project-name ${{ env.PROJECT_NAME }} --branch main
   ```

2. **Add GitHub Secret**
   - Go to: `https://github.com/YOUR-ORG/YOUR-REPO/settings/secrets/actions`
   - Add secret: `CF_API_TOKEN` = your Cloudflare API token

3. **Create Pages project in Cloudflare**
   - Go to: Cloudflare Dashboard → Pages
   - Click **Create application** → **Pages** tab
   - **Direct Upload** method
   - Project name: `your-project-name`
   - Click **Create project**

4. **Push to GitHub**
   - The workflow will trigger and deploy automatically

#### Option B: Git Integration (Easier for Simple Sites)

**Advantages:**
- No GitHub Actions needed
- Cloudflare handles everything
- Simpler setup

**Limitations:**
- Less flexible
- Can't use Pixi or custom tooling easily
- No control over build environment

**Setup:**

1. **Go to Cloudflare Dashboard**
   - Navigate to: Pages → **Create application**

2. **Connect to Git**
   - Choose **Connect to Git**
   - Select **GitHub**
   - Authorize Cloudflare
   - Select your repository

3. **Configure build**
   ```
   Production branch: main

   Build settings:
   - Framework preset: (select if listed, or None)
   - Build command: npm run build
   - Build output directory: out

   Environment variables:
   - Add any needed for build
   ```

4. **Deploy**
   - Cloudflare will build and deploy automatically

### Step 3: Configure DNS

1. **Update main cloudflare-management repo**
   ```hcl
   # Edit envs/prod.tfvars

   subdomain_records = {
     "subdomain" = {
       cname = [
         { value = "your-project.pages.dev", ttl = 3600, proxied = false },
       ]
     }
   }
   ```

2. **Apply DNS changes**
   ```bash
   # In main cloudflare-management repo
   pixi run plan-prod
   pixi run apply-prod
   ```

### Step 4: Add Custom Domain to Pages

1. **In Cloudflare Pages dashboard**
   - Go to your project → **Custom domains**
   - Click **Set up a custom domain**
   - Enter your subdomain (e.g., `subdomain.pythonaisolutions.com`)
   - Cloudflare will verify DNS
   - Click **Activate domain**

2. **Verify HTTPS**
   - Certificate should provision automatically
   - Check site loads at custom domain

### Step 5: Test and Verify

```bash
# Check DNS
dig subdomain.pythonaisolutions.com CNAME +short

# Test HTTPS
curl -I https://subdomain.pythonaisolutions.com

# Test in browser
open https://subdomain.pythonaisolutions.com
```

## Site-Specific Guides

### hih-presentation (Quarto)
✅ **Status**: Setup complete, see `sites/hih-presentation/CLOUDFLARE_DEPLOYMENT_GUIDE.md`

**Build command**: `pixi run build`
**Output directory**: `_site`
**DNS**: `presentations.pythonaisolutions.com` → `hih-presentation.pages.dev`

### pythonaisolutions_website (Next.js)
✅ **Status**: Deployed via Cloudflare Pages (`pythonaisolutions-website`)

**Build command**: `npm run build`
**Output directory**: `out/`
**DNS**: `www.pythonaisolutions.com` → `pythonaisolutions-website.pages.dev`

**Key notes:**
- Static export is enforced via `next.config.mjs (output: 'export')`
- Deployment workflow lives at `sites/pythonaisolutions_website/.github/workflows/deploy.yml`
- Ensure `CF_API_TOKEN` is present in repository secrets
- Consider apex-to-www redirect once DNS migration is finalized

### company-handbook (Quarto)
✅ **Status**: Deployed via Cloudflare Pages (`company-handbook`)

**Build command**: `pixi run build`
**Output directory**: `_site`
**DNS**: `handbook.pythonaisolutions.com` → `company-handbook.pages.dev`

**Key notes:**
- Uses the Quarto workflow mirroring `hih-presentation`
- Keep `routes/_routes.json` in sync if navigation changes
- Validate handbook content in PR previews before merging

### no-strings-resume (Next.js/React)
✅ **Status**: Deployed via Cloudflare Pages (`no-strings-resume`)

**Build command**: `npm run build`
**Output directory**: `dist/`
**DNS**: `resume.pythonaisolutions.com` → `no-strings-resume.pages.dev`

**Key notes:**
- Vite build stays framework-agnostic; no extra env vars needed
- Deployment workflow lives at `sites/no-strings-resume/.github/workflows/deploy.yml`
- Confirm PDF-export functionality in preview deployments before promoting to production

## Rollback Procedures

### If deployment fails:

1. **Keep old platform running**
   - Don't change DNS until new site is verified

2. **Test new deployment first**
   - Visit `project-name.pages.dev` before updating DNS
   - Verify all pages load correctly
   - Test all functionality

3. **If issues after DNS change**
   ```hcl
   # Revert DNS in main repo
   "subdomain" = {
     cname = [
       { value = "old-target.example.com", ttl = 300 },  # Lower TTL for quick changes
     ]
   }
   ```
   ```bash
   pixi run apply-prod
   ```

## Best Practices

1. **Use preview deployments**
   - Test changes in PR previews before merging

2. **Set up redirects**
   - Use `_redirects` file for URL changes
   - Example:
     ```
     /old-page /new-page 301
     ```

3. **Configure headers**
   - Use `_headers` file for security headers
   - Example:
     ```
     /*
       X-Frame-Options: DENY
       X-Content-Type-Options: nosniff
     ```

4. **Monitor performance**
   - Enable Cloudflare Web Analytics
   - Check Core Web Vitals

5. **Set up alerts**
   - Configure deployment notifications in GitHub
   - Set up Cloudflare email alerts for issues

## Common Issues

### "Build failed with exit code 1"
- Check build logs in Pages dashboard
- Verify build command works locally
- Check environment variables are set

### "Custom domain verification failed"
- Verify CNAME exists: `dig subdomain.domain.com CNAME +short`
- Wait 5-10 minutes for DNS propagation
- Ensure you're using Cloudflare DNS

### "Site loads but assets 404"
- Check output directory is correct
- Verify paths in HTML are relative, not absolute
- Check `_routes.json` if using

### "HTTPS certificate not provisioning"
- Wait 15-30 minutes
- Ensure custom domain is activated
- Check for DNS CAA records blocking issuance

## Next Steps

After migrating sites:

1. **Update main README** with new URLs
2. **Archive old deployment methods**
3. **Update documentation** to reference Cloudflare Pages
4. **Set up monitoring** for all sites
5. **Consider**: Migrate K8s apps to Cloudflare (later, more complex)

## Resources

- [Cloudflare Pages Docs](https://developers.cloudflare.com/pages/)
- [Framework Guides](https://developers.cloudflare.com/pages/framework-guides/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)
- [Direct Upload](https://developers.cloudflare.com/pages/platform/direct-upload/)
