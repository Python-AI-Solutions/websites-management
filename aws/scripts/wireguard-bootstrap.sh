#!/usr/bin/env bash
set -euxo pipefail

WG_ADDRESS="${WG_ADDRESS:-10.99.0.1/24}"
WG_PORT="${WG_PORT:-51820}"
FRP_CONTROL_PORT=7005
FRP_SSH_PORT=7006
COUNTRIES=("in" "ie")
IPSET_NAME="geo_ingress_allow"
TMP_DIR="$(mktemp -d)"

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

for country in "${COUNTRIES[@]}"; do
  ZONE_FILE="${TMP_DIR}/${country}.zone"
  curl -fsSL "https://www.ipdeny.com/ipblocks/data/countries/${country}.zone" -o "${ZONE_FILE}"
  while IFS= read -r cidr; do
    [[ -z "${cidr}" ]] && continue
    sudo ipset add "${IPSET_NAME}" "${cidr}" -exist
  done < "${ZONE_FILE}"
done

sudo sh -c "ipset save > /etc/ipset.conf"
sudo systemctl enable --now ipset-persistent

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
