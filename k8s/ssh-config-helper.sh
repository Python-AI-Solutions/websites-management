#!/usr/bin/env bash
# Helper script to extract SSH config and generate terraform.tfvars
# Usage: ./ssh-config-helper.sh <ssh-host-alias>
# Example: ./ssh-config-helper.sh k8s-host

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <ssh-host-alias>"
    echo "Example: $0 k8s-host"
    exit 1
fi

SSH_ALIAS="$1"
OUTPUT_FILE="terraform.tfvars"

# Function to extract SSH config value
get_ssh_config() {
    local key="$1"
    ssh -G "$SSH_ALIAS" 2>/dev/null | grep -i "^${key} " | awk '{print $2}' | head -n1
}

# Extract values from SSH config
TARGET_HOST=$(get_ssh_config "hostname")
TARGET_PORT=$(get_ssh_config "port")
SSH_USER=$(get_ssh_config "user")
IDENTITY_FILE=$(get_ssh_config "identityfile")

# Default to port 22 if not specified
if [ -z "$TARGET_PORT" ]; then
    TARGET_PORT=22
fi

# Expand ~ in identity file path
IDENTITY_FILE="${IDENTITY_FILE/#\~/$HOME}"

# Check for ProxyCommand (indicates bastion/jump host)
PROXY_COMMAND=$(ssh -G "$SSH_ALIAS" 2>/dev/null | grep -i "^proxycommand " | cut -d' ' -f2- || echo "")

# Parse bastion from ProxyCommand if present
BASTION_HOST=""
BASTION_USER=""
BASTION_KEY=""
BASTION_PORT=""
if [ -n "$PROXY_COMMAND" ]; then
    # Try to extract bastion host from ProxyCommand
    # Handles formats like: ssh -W %h:%p user@host
    if [[ "$PROXY_COMMAND" =~ ssh.*@([^ ]+) ]]; then
        BASTION_FULL="${BASH_REMATCH[1]}"
        if [[ "$BASTION_FULL" =~ ([^@]+)@(.+) ]]; then
            BASTION_USER="${BASH_REMATCH[1]}"
            BASTION_HOST="${BASH_REMATCH[2]}"
        else
            BASTION_HOST="$BASTION_FULL"
            BASTION_USER="$SSH_USER"
        fi

        # Try to extract bastion key from ProxyCommand
        if [[ "$PROXY_COMMAND" =~ -i[[:space:]]+([^[:space:]]+) ]]; then
            BASTION_KEY="${BASH_REMATCH[1]}"
            BASTION_KEY="${BASTION_KEY/#\~/$HOME}"
        else
            BASTION_KEY="$IDENTITY_FILE"
        fi

        # Try to extract bastion port from ProxyCommand (-p <port>)
        if [[ "$PROXY_COMMAND" =~ -p[[:space:]]*([0-9]+) ]]; then
            BASTION_PORT="${BASH_REMATCH[1]}"
        fi
    fi

    # Also check if ProxyCommand uses another SSH alias
    if [[ "$PROXY_COMMAND" =~ ssh[[:space:]]+-W[[:space:]]%h:%p[[:space:]]+([^[:space:]]+) ]]; then
        JUMP_ALIAS="${BASH_REMATCH[1]}"
        # Query the jump alias directly
        BASTION_HOST=$(ssh -G "$JUMP_ALIAS" 2>/dev/null | grep -i "^hostname " | awk '{print $2}' | head -n1 || echo "$JUMP_ALIAS")
        BASTION_USER=$(ssh -G "$JUMP_ALIAS" 2>/dev/null | grep -i "^user " | awk '{print $2}' | head -n1 || echo "$SSH_USER")
        BASTION_PORT=$(ssh -G "$JUMP_ALIAS" 2>/dev/null | grep -i "^port " | awk '{print $2}' | head -n1 || echo "22")
        # Get all identity files and prefer non-default ones
        BASTION_KEY_TMP=$(ssh -G "$JUMP_ALIAS" 2>/dev/null | grep -i "^identityfile " | awk '{print $2}' | grep -v -E '(id_rsa|id_dsa|id_ecdsa|id_ed25519)$' | head -n1)
        # If no non-default found, use the first one
        if [ -z "$BASTION_KEY_TMP" ]; then
            BASTION_KEY_TMP=$(ssh -G "$JUMP_ALIAS" 2>/dev/null | grep -i "^identityfile " | awk '{print $2}' | head -n1 || echo "$IDENTITY_FILE")
        fi
        BASTION_KEY="${BASTION_KEY_TMP/#\~/$HOME}"
    fi
fi

# Ensure bastion port defaults to 22 if still empty
if [ -n "$BASTION_HOST" ] && [ -z "$BASTION_PORT" ]; then
    BASTION_PORT=22
fi

# Generate terraform.tfvars
cat > "$OUTPUT_FILE" << EOF
# Generated from SSH config alias: $SSH_ALIAS
# Generated at: $(date)

# IMPORTANT: This setup uses SSH Agent for authentication
# Make sure these keys are loaded: ssh-add -L
# To add keys: ssh-add $IDENTITY_FILE

# SSH Configuration
host                    = "$TARGET_HOST"
host_port               = $TARGET_PORT
ssh_user                = "$SSH_USER"

# Cluster Configuration
cluster_name            = "k8s"

EOF

# Add bastion configuration if detected
if [ -n "$BASTION_HOST" ]; then
    cat >> "$OUTPUT_FILE" << EOF
# Bastion/Jump Host Configuration (detected from ProxyCommand)
# Make sure bastion key is loaded: ssh-add $BASTION_KEY
bastion_host            = "$BASTION_HOST"
bastion_user            = "$BASTION_USER"
bastion_port            = $BASTION_PORT

EOF
else
    cat >> "$OUTPUT_FILE" << EOF
# No bastion/jump host detected
# bastion_host            = ""
# bastion_user            = ""
# bastion_port            = 22

EOF
fi

# Add optional commented-out settings
cat >> "$OUTPUT_FILE" << EOF
# Optional: Customize Kubernetes settings
# kubernetes_version    = "1.30.5"
# pod_cidr             = "10.244.0.0/16"
# service_cidr         = "10.96.0.0/12"

# Optional: ACME/Let's Encrypt for cert-manager
# acme_email                  = "your-email@example.com"
# enable_letsencrypt_staging  = true
EOF

echo "✅ Created $OUTPUT_FILE from SSH config alias: $SSH_ALIAS"
echo ""
echo "Review and edit $OUTPUT_FILE, then run:"
echo "  tofu apply"
