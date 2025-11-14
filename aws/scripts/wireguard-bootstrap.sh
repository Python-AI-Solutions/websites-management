#!/usr/bin/env bash
set -euxo pipefail

WG_ADDRESS="${WG_ADDRESS:-10.99.0.1/24}"
WG_PORT="${WG_PORT:-51820}"
TMP_DIR="$(mktemp -d)"

if [ -n "${WG_PEERS_B64:-}" ]; then
  WG_PEERS_JSON="$(echo "${WG_PEERS_B64}" | base64 --decode)"
else
  WG_PEERS_JSON="[]"
fi

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  wireguard iptables-persistent curl

sudo install -d -m 700 /etc/wireguard

if ! sudo test -f /etc/wireguard/server.key; then
  sudo sh -c 'umask 077 && wg genkey > /etc/wireguard/server.key'
  sudo sh -c 'wg pubkey < /etc/wireguard/server.key > /etc/wireguard/server.pub'
fi

SERVER_KEY="$(sudo cat /etc/wireguard/server.key)"

sudo tee /etc/wireguard/wg0.conf >/dev/null <<CONFIG
[Interface]
Address = ${WG_ADDRESS}
ListenPort = ${WG_PORT}
SaveConfig = true
PrivateKey = ${SERVER_KEY}
CONFIG

sudo chmod 600 /etc/wireguard/wg0.conf

sudo tee /etc/sysctl.d/99-wireguard.conf >/dev/null <<SYSCTL
net.ipv4.ip_forward = 1
SYSCTL

sudo sysctl --system

if sudo systemctl is-enabled --quiet wg-quick@wg0; then
  sudo systemctl restart wg-quick@wg0
else
  sudo systemctl enable --now wg-quick@wg0
fi

# Note: Removed ipset/geo-restriction logic per John's instructions
# The security group now handles access control at the AWS level

allow_port() {
  local proto="$1"
  local port="$2"
  local rule="INPUT -p ${proto} --dport ${port} -j ACCEPT"
  
  if ! sudo iptables -C ${rule} 2>/dev/null; then
    sudo iptables -I ${rule}
  fi
}

# Allow WireGuard port
# NOTE: FRP is kept as emergency-only fallback, see aws/runbooks/FRP_EMERGENCY_ACCESS.md
allow_port udp "${WG_PORT}"

# Save iptables rules
sudo sh -c "iptables-save > /etc/iptables/rules.v4"
sudo systemctl enable --now netfilter-persistent

echo "${WG_PEERS_JSON}" | python3 -c '
import sys, json, subprocess

peers = json.load(sys.stdin)
for peer in peers:
    name = peer.get("name", "unnamed")
    pubkey = peer["public_key"]
    allowed_ips = ",".join(peer.get("allowed_ips", []))
    keepalive = peer.get("persistent_keepalive", 25)
    
    print(f"Adding peer: {name}")
    cmd = [
        "sudo", "wg", "set", "wg0",
        "peer", pubkey,
        "allowed-ips", allowed_ips
    ]
    if keepalive:
        cmd.extend(["persistent-keepalive", str(keepalive)])
    
    subprocess.run(cmd, check=True)
'

sudo wg

# Persist the configuration
sudo sh -c "wg-quick save wg0"

echo "WireGuard server setup complete"
echo "Server public key: $(sudo cat /etc/wireguard/server.pub)"