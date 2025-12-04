#!/usr/bin/env python3
"""
Regenerate a local WireGuard config from Terraform state/vars and optionally
bounce the tunnel via wg-quick.
"""
from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
K8S_DIR = REPO_ROOT / "k8s"
CONFIG_DIR = Path.home() / ".config" / "wireguard"


def run(cmd: list[str], *, cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=True,
        check=check,
    )


def bash(script: str, *, cwd: Path | None = None) -> str:
    proc = run(["bash", "--noprofile", "--norc", "-c", script], cwd=cwd)
    return proc.stdout.strip()


def eval_console(expression: str) -> str:
    quoted = shlex.quote(expression)
    script = f"cd {shlex.quote(str(K8S_DIR))} && printf '%s\\n' {quoted} | tofu console"
    return bash(script)


def decode_console_value(raw: str) -> str:
    raw = raw.strip()
    if raw.startswith('"') and raw.endswith('"'):
        return json.loads(raw)
    return raw


def decode_json_expression(raw: str):
    first = json.loads(raw)
    if isinstance(first, str):
        return json.loads(first)
    return first


def get_bastion_outputs() -> dict:
    script = f"cd {shlex.quote(str(K8S_DIR))} && tofu output -json aws_bastion"
    data = bash(script)
    return json.loads(data)


def update_config(peer_name: str, config_name: str | None, key_file: Path | None, apply_changes: bool) -> None:
    peers = decode_json_expression(eval_console("jsonencode(var.wireguard_peers)"))
    peer = next((p for p in peers if p.get("name") == peer_name), None)
    if not peer:
        print(f"[!] Peer {peer_name!r} not found in wireguard_peers.", file=sys.stderr)
        sys.exit(1)

    bastion_pub = decode_console_value(eval_console("var.bastion_wireguard_public_key"))
    listen_port = int(decode_console_value(eval_console("var.wireguard_listen_port")))
    allowed_ip = peer["allowed_ips"][0]

    outputs = get_bastion_outputs()
    bastion_ip = outputs["public_ip"]

    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    config_stem = config_name or peer_name
    config_path = CONFIG_DIR / f"{config_stem}.conf"
    priv_key_path = key_file or (CONFIG_DIR / f"{config_stem}.key")

    if not priv_key_path.exists():
        print(f"[!] Private key {priv_key_path} is missing. Generate it with `wg genkey > {priv_key_path}`.")
        sys.exit(1)

    private_key = priv_key_path.read_text().strip()
    config_contents = f"""[Interface]
PrivateKey = {private_key}
Address = {allowed_ip}
DNS = 1.1.1.1

[Peer]
PublicKey = {bastion_pub}
Endpoint = {bastion_ip}:{listen_port}
AllowedIPs = 10.99.0.0/24
PersistentKeepalive = 25
"""
    config_path.write_text(config_contents)
    print(f"[+] Updated {config_path} with endpoint {bastion_ip}:{listen_port}")

    if apply_changes:
        down = subprocess.run(["sudo", "wg-quick", "down", str(config_path)], text=True)
        if down.returncode != 0:
            print("[!] wg-quick down reported errors (continuing).")
        up = subprocess.run(["sudo", "wg-quick", "up", str(config_path)], text=True)
        up.check_returncode()
        print("[+] WireGuard tunnel restarted.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Refresh local WireGuard config from Terraform.")
    parser.add_argument("--peer", required=True, help="Name of the peer entry in wireguard_peers (e.g., team-member-1).")
    parser.add_argument("--config-name", help="Override the local config filename stem (defaults to the peer name).")
    parser.add_argument("--key-file", help="Explicit path to the local WireGuard private key.")
    parser.add_argument("--apply", action="store_true", help="Run `wg-quick down/up` after rewriting the config.")
    args = parser.parse_args()

    try:
        key_path = Path(args.key_file).expanduser() if args.key_file else None
        update_config(args.peer, args.config_name, key_path, args.apply)
    except subprocess.CalledProcessError as exc:
        print(exc.stdout or "", file=sys.stderr)
        print(exc.stderr or "", file=sys.stderr)
        sys.exit(exc.returncode)


if __name__ == "__main__":
    main()
