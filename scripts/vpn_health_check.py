#!/usr/bin/env python3
"""
Simple VPN health check:
- ping the bastion WireGuard address
- SSH to bastion
- SSH to Debian via the VPN
"""
from __future__ import annotations

import json
import subprocess
import sys

CHECKS = [
    ("ping_bastion", ["ping", "-c", "1", "10.99.0.1"]),
    ("ssh_bastion", ["ssh", "-o", "BatchMode=yes", "bastion-admin", "true"]),
    ("ssh_debian", ["ssh", "-o", "BatchMode=yes", "debian-vpn", "true"]),
]


def run_check(name: str, cmd: list[str]) -> tuple[str, bool, str]:
    proc = subprocess.run(cmd, text=True, capture_output=True)
    ok = proc.returncode == 0
    details = proc.stdout.strip() if ok else (proc.stderr.strip() or proc.stdout.strip())
    return name, ok, details


def main() -> None:
    results = []
    overall_ok = True
    for name, cmd in CHECKS:
        result = run_check(name, cmd)
        results.append(
            {
                "check": name,
                "ok": result[1],
                "details": result[2],
                "command": " ".join(cmd),
            }
        )
        overall_ok &= result[1]

    print(json.dumps({"ok": overall_ok, "checks": results}, indent=2))
    sys.exit(0 if overall_ok else 1)


if __name__ == "__main__":
    main()
