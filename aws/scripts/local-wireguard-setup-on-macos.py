#!/usr/bin/env python3
"""
Helper to bootstrap a WireGuard peer on macOS and update the Terraform vars.
"""
import ipaddress
import json
import os
import platform
import shutil
import subprocess
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parent.parent.parent
AWS_DIR = REPO_ROOT / "aws"
PEERS_FILE = AWS_DIR / "wireguard-peers.auto.tfvars.json"
CONFIG_DIR = Path.home() / ".config" / "wireguard"
WG_BIN = shutil.which("wg")

# When AllowedIPs is `0.0.0.0/0` the tunnel becomes the default route. To keep
# general internet traffic on the normal interface, limit AllowedIPs to the
# WireGuard subnet (default) or explicitly-specified destinations.
ALLOWED_IPS_ENV_VAR = "WIREGUARD_ALLOWED_IPS"
DEFAULT_ALLOWED_IPS = ["10.99.0.0/24"]


def run(cmd, **kwargs):
    result = subprocess.run(
        cmd,
        check=True,
        text=True,
        capture_output=True,
        **kwargs,
    )
    return result.stdout.strip()


def ensure_dependencies():
    if platform.system() != "Darwin":
        raise SystemExit("This helper only supports macOS (Darwin).")
    if shutil.which("brew") is None:
        raise SystemExit("Homebrew is required: install from https://brew.sh/ first.")
    if shutil.which("wg") is None:
        print("Installing wireguard-tools via Homebrew...")
        subprocess.run(["brew", "install", "wireguard-tools"], check=True)


def prompt(text, default=None):
    if default:
        value = input(f"{text} [{default}]: ").strip()
        return value or default
    return input(f"{text}: ").strip()


def generate_keys(peer_name):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(CONFIG_DIR, 0o700)
    key_path = CONFIG_DIR / f"{peer_name}.key"
    pub_path = CONFIG_DIR / f"{peer_name}.key.pub"
    private_key = run(["wg", "genkey"])
    public_key = run(["wg", "pubkey"], input=private_key)
    key_path.write_text(private_key + "\n")
    pub_path.write_text(public_key + "\n")
    os.chmod(key_path, 0o600)
    os.chmod(pub_path, 0o600)
    return private_key, public_key


def normalized_allowed_ips():
    raw = os.environ.get(ALLOWED_IPS_ENV_VAR, "")
    if raw:
        candidates = [part.strip() for part in raw.replace(",", " ").split() if part.strip()]
        if candidates:
            return candidates
    return list(DEFAULT_ALLOWED_IPS)


def load_peers():
    if PEERS_FILE.exists():
        data = json.loads(PEERS_FILE.read_text())
    else:
        data = {"wireguard_peers": []}
    return data


def save_peers(data):
    PEERS_FILE.write_text(json.dumps(data, indent=2) + "\n")


def next_available_ip(existing):
    used = {ipaddress.ip_network(entry["allowed_ips"][0], strict=False)
            for entry in existing if entry.get("allowed_ips")}
    start = ipaddress.ip_address("10.99.0.10")
    for offset in range(10, 255):
        candidate = ipaddress.ip_network(f"10.99.0.{offset}/32")
        if candidate not in used:
            return str(candidate)
    raise RuntimeError("Ran out of available 10.99.0.x addresses")


def terraform_public_ip():
    # Use bash -c instead of -lc to avoid sourcing .bashrc/.bash_profile
    # which can pollute stdout with echo statements
    env = os.environ.copy()
    # Ensure PATH includes common locations for tofu
    env["PATH"] = f"/opt/homebrew/bin:{env.get('PATH', '')}"
    return run(
        ["bash", "-c", f"cd {AWS_DIR} && tofu output -raw jump_host_public_ip"],
        env=env
    )


def server_public_key():
    return run(["ssh", "bastion-admin", "sudo cat /etc/wireguard/server.pub"])


def server_listen_port():
    output = run(
        ["ssh", "bastion-admin", "sudo wg showconf wg0 | grep ListenPort"]
    )
    return output.split("=")[1].strip()


def write_client_config(peer_name, private_key, server_key, endpoint, allowed_ip, port, allowed_ips):
    conf_path = CONFIG_DIR / f"{peer_name}.conf"
    allowed_ips_text = ", ".join(allowed_ips)
    conf_path.write_text(
        f"""[Interface]
PrivateKey = {private_key}
Address = {allowed_ip}
DNS = 1.1.1.1

[Peer]
PublicKey = {server_key}
Endpoint = {endpoint}:{port}
AllowedIPs = {allowed_ips_text}
PersistentKeepalive = 25
"""
    )
    os.chmod(conf_path, 0o600)
    return conf_path


def main():
    ensure_dependencies()
    peer_name = prompt("Peer name", default=os.uname().nodename)
    data = load_peers()
    peers = data.setdefault("wireguard_peers", [])
    default_ip = next_available_ip(peers)
    allowed_ip = prompt("WireGuard /32 address", default=default_ip)
    private_key, public_key = generate_keys(peer_name)

    # upsert peer entry
    peer_entry = {
        "name": peer_name,
        "public_key": public_key,
        "allowed_ips": [allowed_ip],
        "persistent_keepalive": 25,
    }
    peers = [p for p in peers if p.get("public_key") != public_key]
    peers.append(peer_entry)
    data["wireguard_peers"] = peers
    save_peers(data)

    endpoint_ip = terraform_public_ip()
    server_key = server_public_key()
    listen_port = server_listen_port()
    allowed_ips = normalized_allowed_ips()
    conf_path = write_client_config(
        peer_name, private_key, server_key, endpoint_ip, allowed_ip, listen_port, allowed_ips
    )

    print("\nDone! Next steps:")
    print(f"1. Review/commit {PEERS_FILE.relative_to(REPO_ROOT)}")
    print("2. Apply the Terraform changes:")
    print(f"   cd {AWS_DIR} && tofu apply")
    print(f"3. Bring up the tunnel on this Mac:")
    print(f"   sudo wg-quick up {conf_path}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nAborted.")
