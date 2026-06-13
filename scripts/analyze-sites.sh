#!/usr/bin/env bash
# Analyze sites in the sites/ directory for deployment configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SITES_DIR="${REPO_ROOT}/sites"

print_tfvars_map_keys() {
  local map_name="$1"
  local file="$2"
  local keys

  keys=$(awk -v map_name="${map_name}" '
    $0 == map_name " = {" {
      in_map = 1
      next
    }
    in_map && $0 == "}" {
      in_map = 0
      next
    }
    in_map && $0 ~ /^  "[^"]+"[[:space:]]*=[[:space:]]*\{/ {
      line = $0
      sub(/^  "/, "", line)
      sub(/".*/, "", line)
      print "  - " line
    }
  ' "${file}")

  if [ -n "${keys}" ]; then
    printf '%s\n' "${keys}"
  else
    echo "  - (none)"
  fi
}

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
  submodule_name="sites/${site_name}"
  submodule_url=$(git -C "${REPO_ROOT}" config --file .gitmodules --get "submodule.${submodule_name}.url" 2>/dev/null || true)
  parent_gitlink=$(git -C "${REPO_ROOT}" ls-tree HEAD "${submodule_name}" | awk '$1 == "160000" {print $3}')

  echo "📁 ${site_name}"
  echo "   Path: sites/${site_name}"
  if [ -n "${submodule_url}" ]; then
    echo "   Submodule URL: ${submodule_url}"
  fi
  if [ -n "${parent_gitlink}" ]; then
    echo "   Parent gitlink: ${parent_gitlink}"
  fi

  cd "${site_name}"

  # Check if it's a valid git repo (submodules have .git as a file, not directory)
  if [ ! -e ".git" ]; then
    if [ -n "${submodule_url}" ]; then
      echo "   Status: Submodule registered but not initialized"
    else
      echo "   ⚠️  Not a git repository"
    fi
    cd ..
    continue
  fi

  # Get remote URL
  remote_url=$(git remote get-url origin 2>/dev/null || echo "Unknown")
  echo "   Repository: ${remote_url}"
  if [ -n "${submodule_url}" ] && [ "${remote_url}" != "${submodule_url}" ]; then
    echo "   Warning: initialized origin differs from .gitmodules"
  fi

  # Check for common static site indicators
  has_package_json=false
  has_requirements=false
  has_dockerfile=false
  has_k8s=false
  has_github_workflows=false
  has_cloudflare_pages=false
  deployment_type="Unknown"

  if [ -f "package.json" ]; then
    has_package_json=true
    framework=$(cat package.json | grep -o '"@.*":\s*".*"' | head -1 || echo "")

    # Check for common frameworks
    if grep -q "next" package.json 2>/dev/null; then
      deployment_type="Next.js (Static/SSR)"
    elif grep -q "react" package.json 2>/dev/null; then
      deployment_type="React (Static)"
    elif grep -q '"vite"' package.json 2>/dev/null; then
      deployment_type="Vite (Static)"
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

  if compgen -G ".github/workflows/*.yml" >/dev/null || compgen -G ".github/workflows/*.yaml" >/dev/null; then
    has_github_workflows=true
  fi

  if [ -f "wrangler.toml" ] || grep -Rqs "wrangler pages deploy\|cloudflare/pages-action" .github/workflows 2>/dev/null; then
    has_cloudflare_pages=true
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
  [ "$has_github_workflows" = true ] && echo "     - GitHub Actions workflows"
  [ "$has_cloudflare_pages" = true ] && echo "     - Cloudflare Pages deployment"

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

  echo "Subdomain records:"
  print_tfvars_map_keys "subdomain_records" envs/prod.tfvars

  echo ""
  echo "Cloudflare Pages projects:"
  print_tfvars_map_keys "pages_projects" envs/prod.tfvars

  echo ""
  echo "Additional zones:"
  print_tfvars_map_keys "additional_zones" envs/prod.tfvars

  echo ""
  echo "Additional Pages domain groups:"
  print_tfvars_map_keys "additional_pages_domains" envs/prod.tfvars

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
