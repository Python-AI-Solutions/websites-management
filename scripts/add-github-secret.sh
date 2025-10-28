#!/usr/bin/env bash
# Add CF_API_TOKEN secret to a GitHub repository
#
# Usage: ./scripts/add-github-secret.sh REPO_NAME
#
# Example:
#   ./scripts/add-github-secret.sh hih-presentation
#
# Prerequisites:
# - gh CLI installed and authenticated
# - CF_API_TOKEN environment variable set (or will read from .env)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if gh is installed
if ! command -v gh &> /dev/null; then
  echo -e "${RED}Error: gh CLI is not installed${NC}"
  echo ""
  echo "Install it with:"
  echo "  brew install gh"
  echo ""
  echo "Or see: https://cli.github.com/"
  exit 1
fi

# Check if gh is authenticated
if ! gh auth status &> /dev/null; then
  echo -e "${RED}Error: gh CLI is not authenticated${NC}"
  echo ""
  echo "Authenticate with:"
  echo "  gh auth login"
  exit 1
fi

if [ $# -lt 1 ]; then
  echo -e "${RED}Error: Missing repository name${NC}"
  echo ""
  echo "Usage: $0 REPO_NAME"
  echo ""
  echo "Example:"
  echo "  $0 hih-presentation"
  echo ""
  echo "This will add CF_API_TOKEN secret to:"
  echo "  github.com/python-ai-solutions/REPO_NAME"
  exit 1
fi

REPO_NAME="$1"
DEFAULT_ORG="python-ai-solutions"

# Allow specifying org/repo format
if [[ "$REPO_NAME" == *"/"* ]]; then
  REPO="$REPO_NAME"
else
  REPO="$DEFAULT_ORG/$REPO_NAME"
fi

# Try to load CF_API_TOKEN from environment or .env
if [ -z "${CF_API_TOKEN:-}" ]; then
  if [ -f ".env" ]; then
    source .env
  fi
fi

if [ -z "${CF_API_TOKEN:-}" ]; then
  echo -e "${YELLOW}CF_API_TOKEN not found in environment or .env file${NC}"
  echo ""
  echo "Please enter your Cloudflare API token:"
  read -s CF_API_TOKEN
  echo ""
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Adding GitHub Secret${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Repository: $REPO"
echo "Secret:     CF_API_TOKEN"
echo ""

# Add the secret
if echo "$CF_API_TOKEN" | gh secret set CF_API_TOKEN --repo "$REPO"; then
  echo ""
  echo -e "${GREEN}✓ Successfully added CF_API_TOKEN secret to $REPO${NC}"
  echo ""
  echo "The deployment workflow can now deploy to Cloudflare Pages."
else
  echo ""
  echo -e "${RED}✗ Failed to add secret${NC}"
  echo ""
  echo "You can add it manually:"
  echo "  1. Go to: https://github.com/$REPO/settings/secrets/actions"
  echo "  2. Click 'New repository secret'"
  echo "  3. Name: CF_API_TOKEN"
  echo "  4. Value: [your Cloudflare API token]"
  exit 1
fi
