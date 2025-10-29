#!/usr/bin/env python3
"""
DNS and site verification script.

Replaces the legacy verify-dns shell script with richer validation:
- Confirms Cloudflare nameservers, apex records, and subdomain records match tfvars/state.
- Validates Cloudflare Pages projects (CNAME targets + HTTPS availability).
- Reports actionable failures and exits non-zero when inconsistencies are found.
"""

from __future__ import annotations

import argparse
import json
import ssl
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Tuple

import dns.exception
import dns.resolver
import hcl2

ROOT_DIR = Path(__file__).resolve().parent.parent
TFVARS_PATH = ROOT_DIR / "envs" / "prod.tfvars"
TOFU_DIR = ROOT_DIR / "root"
DEFAULT_TIMEOUT = 5


@dataclass
class CheckResult:
    expectation: str
    ok: bool
    details: str


def load_tfvars(path: Path) -> Dict:
    with path.open("r", encoding="utf-8") as fp:
        return hcl2.load(fp)


def load_tofo_outputs() -> Dict:
    cmd = [
        "bash",
        "-lc",
        "source scripts/load-env.sh && cd root && tofu output -json",
    ]
    proc = subprocess.run(
        cmd,
        cwd=ROOT_DIR,
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            "Failed to execute `tofu output -json`. "
            f"stdout: {proc.stdout}\nstderr: {proc.stderr}"
        )
    stdout = proc.stdout.strip()
    json_start = stdout.find("{")
    if json_start == -1:
        raise RuntimeError(
            "Unexpected output from `tofu output -json`, unable to parse JSON:\n"
            f"{stdout}"
        )
    return json.loads(stdout[json_start:])


def resolve_records(name: str, record_type: str) -> List[str]:
    resolver = dns.resolver.Resolver()
    resolver.lifetime = DEFAULT_TIMEOUT
    record_type = record_type.upper()

    try:
        answers = resolver.resolve(name, record_type, lifetime=DEFAULT_TIMEOUT)
    except (dns.resolver.NXDOMAIN, dns.resolver.NoAnswer, dns.exception.Timeout):
        return []

    clean: List[str] = []
    for rdata in answers:
        if record_type == "A":
            clean.append(rdata.address)
        elif record_type == "CNAME":
            clean.append(rdata.target.to_text().rstrip(".").lower())
        elif record_type == "TXT":
            clean.append("".join(part.decode("utf-8") for part in rdata.strings))
        elif record_type == "MX":
            clean.append(rdata.exchange.to_text().rstrip(".").lower())
        elif record_type == "NS":
            clean.append(rdata.target.to_text().rstrip(".").lower())
        else:
            clean.append(rdata.to_text().rstrip("."))
    return sorted(clean)


def compare_records(
    fqdn: str,
    record_type: str,
    expected: Sequence[str],
    results: List[CheckResult],
    expectation: str,
) -> None:
    expected_clean = sorted(value.rstrip(".").lower() for value in expected)
    actual = resolve_records(fqdn, record_type)
    ok = actual == expected_clean
    detail = (
        f"{fqdn} {record_type}: expected {expected_clean}, observed {actual}"
    )
    results.append(CheckResult(expectation=expectation, ok=ok, details=detail))


def check_nameservers(domain: str, expected: Sequence[str], results: List[CheckResult]) -> None:
    compare_records(
        domain,
        "NS",
        expected,
        results,
        expectation=f"Asserts DNS is delegated to Cloudflare nameservers for {domain}",
    )


def check_apex(domain: str, apex_records: Dict, results: List[CheckResult]) -> None:
    for record_type in ("a", "txt", "mx"):
        entries = apex_records.get(record_type, [])
        if not entries:
            continue
        expected_values = [entry["value"] for entry in entries]
        expectation = f"Asserts apex {record_type.upper()} records for {domain} match configuration"
        compare_records(domain, record_type, expected_values, results, expectation)


def check_subdomains(
    domain: str, subdomain_records: Dict, results: List[CheckResult]
) -> None:
    for sub_name, record_bundle in subdomain_records.items():
        fqdn = f"{sub_name}.{domain}"
        for record_type in ("a", "cname", "txt"):
            entries = record_bundle.get(record_type)
            if not entries:
                continue
            expected_values = [entry["value"] for entry in entries]
            expectation = (
                f"Asserts {fqdn} {record_type.upper()} records align with managed config"
            )
            compare_records(fqdn, record_type, expected_values, results, expectation)


def http_status(url: str, timeout: int = DEFAULT_TIMEOUT) -> Tuple[bool, str]:
    req = urllib.request.Request(
        url,
        method="GET",
        headers={"User-Agent": "cloudflare-management-verifier/1.0"},
    )
    context = ssl.create_default_context()
    try:
        with urllib.request.urlopen(req, context=context, timeout=timeout) as resp:
            status = resp.status
            ok = 200 <= status < 400
            return ok, f"{status} {resp.reason}"
    except urllib.error.HTTPError as err:
        return False, f"{err.code} {err.reason}"
    except urllib.error.URLError as err:
        return False, str(err.reason)


def check_pages_projects(
    pages_projects_config: Dict,
    pages_projects_outputs: Dict,
    results: List[CheckResult],
) -> None:
    for project_name, config in pages_projects_config.items():
        custom_domain = config.get("custom_domain", "")
        expected_pages_host = f"{project_name}.pages.dev"

        if custom_domain:
            compare_records(
                custom_domain,
                "CNAME",
                [expected_pages_host],
                results,
                expectation=f"Asserts {custom_domain} CNAME points to {expected_pages_host}",
            )

            ok, status_text = http_status(f"https://{custom_domain}")
            details = f"HTTPS check for https://{custom_domain}: {status_text}"
            results.append(
                CheckResult(
                    expectation=f"Asserts https://{custom_domain} responds successfully",
                    ok=ok,
                    details=details,
                )
            )

        pages_output = pages_projects_outputs.get(project_name)
        if not pages_output:
            results.append(
                CheckResult(
                    expectation=f"Asserts Cloudflare Pages project metadata exists for {project_name}",
                    ok=False,
                    details="Terraform outputs missing pages project details. Run `pixi run plan-prod` / `pixi run apply-prod`.",
                )
            )
            continue

        pages_dev_url = pages_output.get("pages_dev_url") or expected_pages_host
        pages_dev_url = pages_dev_url.strip("/")

        ok, status_text = http_status(f"https://{pages_dev_url}")
        results.append(
            CheckResult(
                expectation=f"Asserts https://{pages_dev_url} responds successfully",
                ok=ok,
                details=f"HTTPS check for https://{pages_dev_url}: {status_text}",
            )
        )


def summarize(results: Iterable[CheckResult]) -> int:
    failures = [r for r in results if not r.ok]
    passes = [r for r in results if r.ok]

    header = "=" * 37
    print(header)
    print(" Cloudflare DNS + Pages Verification")
    print(header)
    print("")
    ordered = list(results)
    for idx, result in enumerate(ordered):
        prefix = "✓" if result.ok else "✗"
        print(f"{result.expectation}")
        print(f"  {prefix} {result.details}")
        if idx != len(ordered) - 1:
            print("")

    print()
    print(f"Checks passed: {len(passes)}")
    print(f"Checks failed: {len(failures)}")
    print()

    if failures:
        print("Verification FAILED.")
        return 1

    print("Verification succeeded.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify Cloudflare DNS records and Pages deployments."
    )
    parser.add_argument(
        "--tfvars",
        default=str(TFVARS_PATH),
        help="Path to tfvars file (default: envs/prod.tfvars)",
    )
    args = parser.parse_args()

    tfvars_data = load_tfvars(Path(args.tfvars))
    outputs = load_tofo_outputs()

    domain = tfvars_data.get("zone_name") or outputs["zone_name"]["value"]
    apex_records = tfvars_data.get("apex_records", {})
    subdomain_records = tfvars_data.get("subdomain_records", {})
    pages_projects = tfvars_data.get("pages_projects", {})
    pages_outputs_meta = outputs.get("pages_projects") or {}
    if isinstance(pages_outputs_meta, dict):
        pages_projects_outputs = pages_outputs_meta.get("value", {})
    else:
        pages_projects_outputs = {}

    name_servers = outputs.get("name_servers", {}).get("value", [])

    results: List[CheckResult] = []
    if name_servers:
        check_nameservers(domain, name_servers, results)
    else:
        results.append(
            CheckResult(
                expectation=f"Asserts DNS is delegated to Cloudflare nameservers for {domain}",
                ok=False,
                details="Unable to determine expected nameservers from tofu outputs.",
            )
        )

    check_apex(domain, apex_records, results)
    check_subdomains(domain, subdomain_records, results)
    check_pages_projects(pages_projects, pages_projects_outputs, results)

    return summarize(results)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
