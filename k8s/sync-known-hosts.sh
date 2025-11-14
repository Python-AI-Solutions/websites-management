#!/usr/bin/env bash
# Helper script to sync custom known_hosts entries to default known_hosts
# This is needed because Terraform doesn't support custom known_hosts files
#
# Usage: ./sync-known-hosts.sh [custom-known-hosts-file]

set -euo pipefail

CUSTOM_KNOWN_HOSTS="${1:-$HOME/.ssh/known_hosts.paijump}"
DEFAULT_KNOWN_HOSTS="$HOME/.ssh/known_hosts"

if [ ! -f "$CUSTOM_KNOWN_HOSTS" ]; then
    echo "❌ Custom known_hosts file not found: $CUSTOM_KNOWN_HOSTS"
    exit 1
fi

echo "📝 Syncing known_hosts entries from custom file..."
echo "   From: $CUSTOM_KNOWN_HOSTS"
echo "   To:   $DEFAULT_KNOWN_HOSTS"

# Create default known_hosts if it doesn't exist
touch "$DEFAULT_KNOWN_HOSTS"

# Extract localhost entries from custom known_hosts (with or without port)
LOCALHOST_ENTRIES=$(grep -E '^(\[)?localhost' "$CUSTOM_KNOWN_HOSTS" || echo "")

if [ -z "$LOCALHOST_ENTRIES" ]; then
    echo "⚠️  No localhost entries found in custom known_hosts"
    exit 0
fi

# Remove existing localhost entries from default known_hosts (with and without ports)
echo "🗑️  Removing old localhost entries from default known_hosts..."
ssh-keygen -R localhost -f "$DEFAULT_KNOWN_HOSTS" 2>/dev/null || true
ssh-keygen -R "[localhost]:7006" -f "$DEFAULT_KNOWN_HOSTS" 2>/dev/null || true

# Add entries from custom known_hosts
echo "✅ Adding localhost entries from custom known_hosts..."
echo "$LOCALHOST_ENTRIES" >> "$DEFAULT_KNOWN_HOSTS"

echo "✅ Sync complete!"
echo ""
echo "Localhost entries synced:"
echo "$LOCALHOST_ENTRIES" | sed 's/^/   /'
