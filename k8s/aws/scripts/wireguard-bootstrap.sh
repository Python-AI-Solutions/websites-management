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
  wireguard iptables-persistent curl fail2ban

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

# Rate-limit the WireGuard listener to dampen brute-force/flood attempts
configure_wireguard_firewall() {
  local port="$1"

  # Remove any legacy accept-all rules for the port
  sudo iptables -D INPUT -p udp --dport "${port}" -j ACCEPT 2>/dev/null || true

  # Allow legitimate traffic with a generous global rate limit
  if ! sudo iptables -C INPUT -p udp --dport "${port}" -m limit --limit 200/second --limit-burst 400 -j ACCEPT 2>/dev/null; then
    sudo iptables -I INPUT -p udp --dport "${port}" -m limit --limit 200/second --limit-burst 400 -j ACCEPT
  fi

  # Drop abusive sources that exceed per-IP thresholds
  if ! sudo iptables -C INPUT -p udp --dport "${port}" -m hashlimit --hashlimit-name wg-flood --hashlimit-mode srcip --hashlimit-above 100/second --hashlimit-burst 200 -j DROP 2>/dev/null; then
    sudo iptables -A INPUT -p udp --dport "${port}" -m hashlimit --hashlimit-name wg-flood --hashlimit-mode srcip --hashlimit-above 100/second --hashlimit-burst 200 -j DROP
  fi
}

# NOTE: FRP is kept as emergency-only fallback, see aws/runbooks/FRP_EMERGENCY_ACCESS.md
configure_wireguard_firewall "${WG_PORT}"

# Harden SSH with fail2ban (protects bastion login surface)
sudo tee /etc/fail2ban/jail.d/paas-hardening.conf >/dev/null <<'JAIL'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
backend  = systemd
JAIL

sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban

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
