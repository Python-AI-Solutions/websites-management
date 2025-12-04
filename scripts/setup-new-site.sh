#!/usr/bin/env bash
# Setup a new static site for Cloudflare Pages deployment
#
# Usage: ./scripts/setup-new-site.sh PROJECT_NAME SUBDOMAIN BUILD_COMMAND BUILD_DIR
#
# Example:
#   ./scripts/setup-new-site.sh my-blog blog "npm run build" "out"
#
# This script will:
# 1. Add the site configuration to envs/prod.tfvars
# 2. Show instructions for adding GitHub secret
# 3. Show instructions for copying workflow template

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 4 ]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  echo ""
  echo "Usage: $0 PROJECT_NAME SUBDOMAIN BUILD_COMMAND BUILD_DIR"
  echo ""
  echo "Arguments:"
  echo "  PROJECT_NAME   - Name of the Cloudflare Pages project (e.g., 'my-blog')"
  echo "  SUBDOMAIN      - Subdomain for the site (e.g., 'blog' for blog.example.com)"
  echo "  BUILD_COMMAND  - Command to build the site (e.g., 'pixi run build' or 'npm run build')"
  echo "  BUILD_DIR      - Output directory after build (e.g., '_site', 'out', 'dist')"
  echo ""
  echo "Example:"
  echo "  $0 company-handbook handbook 'pixi run build' '_site'"
  exit 1
fi

PROJECT_NAME="$1"
SUBDOMAIN="$2"
BUILD_COMMAND="$3"
BUILD_DIR="$4"

ZONE_NAME="example.com"
CUSTOM_DOMAIN="${SUBDOMAIN}.${ZONE_NAME}"
TFVARS_FILE="envs/prod.tfvars"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Cloudflare Pages Site Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Project Configuration:${NC}"
echo "  Project Name:    $PROJECT_NAME"
echo "  Custom Domain:   $CUSTOM_DOMAIN"
echo "  Build Command:   $BUILD_COMMAND"
echo "  Build Directory: $BUILD_DIR"
echo ""

# Check if project already exists in tfvars
if grep -q "\"$PROJECT_NAME\"" "$TFVARS_FILE" 2>/dev/null; then
  echo -e "${YELLOW}Warning: Project '$PROJECT_NAME' already exists in $TFVARS_FILE${NC}"
  echo "Skipping Terraform configuration update."
  echo ""
else
  # Create the Terraform configuration block
  cat >> "$TFVARS_FILE" << EOF

  "$PROJECT_NAME" = {
    production_branch = "main"
    build_command     = "$BUILD_COMMAND"
    destination_dir   = "$BUILD_DIR"
    custom_domain     = "$CUSTOM_DOMAIN"
    dns_ttl           = 3600
    dns_proxied       = false
  }
EOF

  # Fix formatting - ensure the closing brace is at the right level
  # (This is a bit hacky, but works for our use case)
  if ! grep -q "^}$" "$TFVARS_FILE"; then
    echo "}" >> "$TFVARS_FILE"
  fi

  echo -e "${GREEN}✓ Added project configuration to $TFVARS_FILE${NC}"
  echo ""
fi

# Show next steps
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Next Steps${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}1. Apply Terraform configuration${NC}"
echo "   This will create the Cloudflare Pages project and configure DNS:"
echo ""
echo "   cd $(dirname $0)/.."
echo "   pixi run plan-prod    # Review changes"
echo "   pixi run apply-prod   # Apply changes"
echo ""

echo -e "${GREEN}2. Add GitHub secret to site repository${NC}"
echo "   The deployment workflow needs your Cloudflare API token:"
echo ""
echo "   a. Go to: https://github.com/YOUR-ORG/YOUR-REPO/settings/secrets/actions"
echo "   b. Click 'New repository secret'"
echo "   c. Name: CF_API_TOKEN"
echo "   d. Value: Your Cloudflare API token (from .env file)"
echo "   e. Click 'Add secret'"
echo ""

echo -e "${GREEN}3. Copy deployment workflow to site repository${NC}"
echo "   Copy the template and customize for your site:"
echo ""
echo "   mkdir -p sites/$PROJECT_NAME/.github/workflows"
echo "   cp .github/workflows/templates/cloudflare-pages-deploy.yml \\"
echo "      sites/$PROJECT_NAME/.github/workflows/deploy.yml"
echo ""
echo "   Then edit the file and change:"
echo "   - PROJECT_NAME: \"$PROJECT_NAME\""
echo "   - BUILD_DIR: \"$BUILD_DIR\""
echo "   - Build command in 'Build site' step: $BUILD_COMMAND"
echo "   - Uncomment/customize setup steps for your framework"
echo ""

echo -e "${GREEN}4. (Optional) Add routing/headers configuration${NC}"
echo "   If needed, add to your site repository:"
echo ""
echo "   # Routing configuration"
echo "   mkdir -p sites/$PROJECT_NAME/routes"
echo "   cat > sites/$PROJECT_NAME/routes/_routes.json << 'EOF'"
echo "   {"
echo "     \"version\": 1,"
echo "     \"include\": [\"/*\"],"
echo "     \"exclude\": []"
echo "   }"
echo "   EOF"
echo ""
echo "   # Add copy step to workflow after build:"
echo "   cp routes/_routes.json \$BUILD_DIR/"
echo ""

echo -e "${GREEN}5. Commit and deploy${NC}"
echo "   Push your changes to trigger the first deployment:"
echo ""
echo "   cd sites/$PROJECT_NAME"
echo "   git add .github/"
echo "   git commit -m 'Add Cloudflare Pages deployment workflow'"
echo "   git push"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "After deployment completes, verify:"
echo ""
echo "  # Check DNS"
echo "  dig $CUSTOM_DOMAIN CNAME +short"
echo "  # Should show: $PROJECT_NAME.pages.dev"
echo ""
echo "  # Test HTTPS"
echo "  curl -I https://$CUSTOM_DOMAIN"
echo ""
echo "  # Open in browser"
echo "  open https://$CUSTOM_DOMAIN"
echo ""

echo -e "${GREEN}✓ Setup script completed${NC}"
echo ""
