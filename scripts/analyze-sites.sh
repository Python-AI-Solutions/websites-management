#!/usr/bin/env bash
# Analyze sites in the sites/ directory for deployment configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SITES_DIR="${REPO_ROOT}/sites"

echo "====================================="
echo "Sites Analysis"
echo "====================================="
echo ""

if [ ! -d "${SITES_DIR}" ]; then
  echo "Error: sites/ directory not found"
  exit 1
fi

cd "${SITES_DIR}"

for site in */; do
  site_name=$(basename "$site")
  echo "📁 ${site_name}"
  echo "   Path: sites/${site_name}"

  cd "${site_name}"

  # Check if it's a valid git repo (submodules have .git as a file, not directory)
  if [ ! -e ".git" ]; then
    echo "   ⚠️  Not a git repository (submodule may not be initialized)"
    cd ..
    continue
  fi

  # Get remote URL
  remote_url=$(git remote get-url origin 2>/dev/null || echo "Unknown")
  echo "   Repository: ${remote_url}"

  # Check for common static site indicators
  has_package_json=false
  has_requirements=false
  has_dockerfile=false
  has_k8s=false
  deployment_type="Unknown"

  if [ -f "package.json" ]; then
    has_package_json=true
    framework=$(cat package.json | grep -o '"@.*":\s*".*"' | head -1 || echo "")

    # Check for common frameworks
    if grep -q "next" package.json 2>/dev/null; then
      deployment_type="Next.js (Static/SSR)"
    elif grep -q "react" package.json 2>/dev/null; then
      deployment_type="React (Static)"
    elif grep -q "vue" package.json 2>/dev/null; then
      deployment_type="Vue (Static)"
    elif grep -q "svelte" package.json 2>/dev/null; then
      deployment_type="Svelte (Static)"
    else
      deployment_type="Node.js app"
    fi
  fi

  if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    has_requirements=true
    if [ -f "manage.py" ]; then
      deployment_type="Django app"
    elif grep -q "fastapi\|uvicorn" requirements.txt 2>/dev/null; then
      deployment_type="FastAPI app"
    elif grep -q "flask" requirements.txt 2>/dev/null; then
      deployment_type="Flask app"
    elif grep -q "streamlit" requirements.txt 2>/dev/null; then
      deployment_type="Streamlit app"
    else
      deployment_type="Python app"
    fi
  fi

  if [ -f "Dockerfile" ]; then
    has_dockerfile=true
  fi

  if [ -d "k8s" ] || [ -d "kubernetes" ] || [ -f "deployment.yaml" ]; then
    has_k8s=true
    deployment_type="${deployment_type} (K8s)"
  fi

  # Check for static site generators
  if [ -f "config.toml" ] || [ -f "config.yaml" ]; then
    deployment_type="Hugo (Static)"
  elif [ -f "gatsby-config.js" ]; then
    deployment_type="Gatsby (Static)"
  elif [ -f "eleventy.config.js" ] || [ -f ".eleventy.js" ]; then
    deployment_type="Eleventy (Static)"
  fi

  echo "   Deployment Type: ${deployment_type}"

  # List key files
  echo "   Key Files:"
  [ "$has_package_json" = true ] && echo "     - package.json"
  [ "$has_requirements" = true ] && echo "     - requirements.txt / pyproject.toml"
  [ "$has_dockerfile" = true ] && echo "     - Dockerfile"
  [ "$has_k8s" = true ] && echo "     - K8s configs"
  [ -f "README.md" ] && echo "     - README.md"
  [ -f ".github/workflows/"*.yml ] && echo "     - GitHub Actions workflows"

  # Check for Cloudflare Pages indicator
  if [ -f "wrangler.toml" ]; then
    echo "     - wrangler.toml (Cloudflare Workers/Pages)"
  fi

  # Get recent activity
  last_commit=$(git log -1 --format="%cr" 2>/dev/null || echo "Unknown")
  echo "   Last commit: ${last_commit}"

  cd ..
  echo ""
done

echo "====================================="
echo "DNS Records from prod.tfvars"
echo "====================================="
echo ""

if [ -f "${REPO_ROOT}/envs/prod.tfvars" ]; then
  cd "${REPO_ROOT}"

  echo "Subdomains currently in DNS:"
  grep -E '^\s+"[^"]+"\s+=\s+\{' envs/prod.tfvars | sed 's/.*"\([^"]*\)".*/  - \1/'

  echo ""
  echo "Consider mapping these to sites in sites/README.md"
else
  echo "⚠️  prod.tfvars not found"
fi

echo ""
echo "====================================="
echo "Recommendations"
echo "====================================="
echo ""
echo "1. Update sites/README.md with deployment details for each site"
echo "2. Verify DNS records in envs/prod.tfvars match actual deployments"
echo "3. For K8s apps, ensure IPs match load balancer IPs"
echo "4. For static sites, consider migrating to Cloudflare Pages"
echo ""
