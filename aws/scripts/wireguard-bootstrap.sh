#!/usr/bin/env bash
set -euxo pipefail

WG_ADDRESS="${WG_ADDRESS:-10.99.0.1/24}"
WG_PORT="${WG_PORT:-51820}"
FRP_CONTROL_PORT=7005
FRP_SSH_PORT=7006
IPSET_NAME="geo_ingress_allow"
TMP_DIR="$(mktemp -d)"
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_ROOT}/wireguard-data"
INDIA_FILE="${DATA_DIR}/india_cidrs.txt"
IRELAND_FILE="${DATA_DIR}/ireland_cidrs.txt"

if [ ! -f "${INDIA_FILE}" ] || [ ! -f "${IRELAND_FILE}" ]; then
  echo "CIDR data files not found under ${DATA_DIR}" >&2
  exit 1
fi

mapfile -t INDIA_CIDRS < "${INDIA_FILE}"
mapfile -t IRELAND_CIDRS < "${IRELAND_FILE}"

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
  wireguard ipset ipset-persistent iptables-persistent curl

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

sudo ipset create "${IPSET_NAME}" hash:net -exist
sudo ipset flush "${IPSET_NAME}"

for cidr in "${INDIA_CIDRS[@]}"; do
  cidr="${cidr//[$'\\t\\r\\n']/}"
  [ -z "${cidr}" ] && continue
  sudo ipset add "${IPSET_NAME}" "${cidr}" -exist
done

for cidr in "${IRELAND_CIDRS[@]}"; do
  cidr="${cidr//[$'\\t\\r\\n']/}"
  [ -z "${cidr}" ] && continue
  sudo ipset add "${IPSET_NAME}" "${cidr}" -exist
done

sudo sh -c "ipset save > /etc/ipset.conf"
sudo systemctl enable --now netfilter-persistent

allow_port() {
  local proto="$1"
  local port="$2"

  if ! sudo iptables -C INPUT -i lo -p "${proto}" --dport "${port}" -j ACCEPT 2>/dev/null; then
    sudo iptables -I INPUT -i lo -p "${proto}" --dport "${port}" -j ACCEPT
  fi

  if ! sudo iptables -C INPUT -p "${proto}" --dport "${port}" -m set --match-set "${IPSET_NAME}" src -j ACCEPT 2>/dev/null; then
    sudo iptables -I INPUT -p "${proto}" --dport "${port}" -m set --match-set "${IPSET_NAME}" src -j ACCEPT
  fi

  if ! sudo iptables -C INPUT -p "${proto}" --dport "${port}" -j DROP 2>/dev/null; then
    sudo iptables -A INPUT -p "${proto}" --dport "${port}" -j DROP
  fi
}

allow_port udp "${WG_PORT}"
allow_port tcp "${FRP_CONTROL_PORT}"
allow_port tcp "${FRP_SSH_PORT}"

sudo netfilter-persistent save

configure_peers() {
  local peers_json="$1"
  python3 - "$peers_json" <<'PY'
import json, sys
peers = json.loads(sys.argv[1])
for peer in peers:
    pub = peer.get("public_key")
    allowed = peer.get("allowed_ips") or []
    if not pub or not allowed:
        continue
    keepalive = peer.get("persistent_keepalive", 25)
    endpoint = peer.get("endpoint", "")
    name = peer.get("name", "")
    print("|".join([
        pub,
        ",".join(allowed),
        str(keepalive),
        endpoint,
        name.replace("|", "_")
    ]))
PY
}

PEERS_OUTPUT="$(configure_peers "${WG_PEERS_JSON}")"

if [ -n "$PEERS_OUTPUT" ]; then
  EXISTING_PEERS=$(sudo wg show wg0 peers || true)
  while read -r current_peer; do
    [ -z "$current_peer" ] && continue
    if ! grep -q "^${current_peer}|" <<< "$PEERS_OUTPUT"; then
      sudo wg set wg0 peer "$current_peer" remove
    fi
  done <<< "$EXISTING_PEERS"

  while IFS="|" read -r pub allowed keepalive endpoint peer_name; do
    [ -z "$pub" ] && continue
    sudo wg set wg0 peer "$pub" remove 2>/dev/null || true
    cmd=(sudo wg set wg0 peer "$pub" allowed-ips "$allowed" persistent-keepalive "$keepalive")
    if [ -n "$endpoint" ]; then
      cmd+=("endpoint" "$endpoint")
    fi
    "${cmd[@]}"
  done <<< "$PEERS_OUTPUT"
fi
