#!/usr/bin/env bash
# Wrapper script to apply Terraform with custom known_hosts support
#
# This script:
# 1. Syncs custom known_hosts entries to default location
# 2. Ensures SSH keys are loaded in agent
# 3. Runs tofu apply with your configuration
#
# Usage: ./apply.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔧 Kubernetes Cluster Setup"
echo "=============================="
echo ""

# Check if k8s.tfvars exists
if [ ! -f "k8s.tfvars" ]; then
    echo "❌ k8s.tfvars not found!"
    echo "   Run: ./ssh-config-helper.sh k8s-host"
    echo "   Or:  cp k8s.tfvars.example k8s.tfvars"
    exit 1
fi

# Sync known_hosts entries
echo "📝 Step 1: Syncing known_hosts entries..."
if [ -f "$HOME/.ssh/known_hosts.paijump" ]; then
    ./sync-known-hosts.sh
else
    echo "   No custom known_hosts file found, skipping sync"
fi
echo ""

# Check SSH agent
echo "🔑 Step 2: Checking SSH agent..."
if ! ssh-add -l &>/dev/null; then
    echo "❌ SSH agent is not running or has no keys!"
    echo "   Add your keys:"
    echo "     ssh-add ~/.ssh/id_rsa"
    echo "     ssh-add ~/.ssh/jumpproxy"
    exit 1
fi

echo "   Keys loaded:"
ssh-add -l | sed 's/^/     /'
echo ""

# Run terraform apply
echo "🚀 Step 3: Running OpenTofu apply..."
echo ""
exec tofu apply -var-file=k8s.tfvars "$@"
