#!/usr/bin/env python3
"""
Interactive Desktop OAuth smoke-test for the public MLflow endpoint.

The script guides a user through:
1. Launching the Google OAuth flow (browser window).
2. Exchanging the resulting ID token for access.
3. Hitting the public MLflow endpoint through oauth2-proxy to list experiments.

It requires mlflow, requests, and google-auth-oauthlib to be installed in the local environment.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import requests
import urllib3
from google_auth_oauthlib.flow import InstalledAppFlow

try:
    import mlflow
except ModuleNotFoundError as exc:  # noqa: N818
    print(
        "mlflow is not installed in this Python environment. "
        "Install it (e.g. `pip install mlflow google-auth-oauthlib requests`) and rerun.",
        file=sys.stderr,
    )
    raise SystemExit(1) from exc


DEFAULT_CLIENT_SECRET = (
    Path(__file__).resolve().parents[2] / "client_secret_1098946209440-c5crpupjjv3p179ok6n5snc37s0fvd16.apps.googleusercontent.com.json"
)
SCOPES = ["openid", "email", "profile"]
MLFLOW_BASE = "https://mlflow.cervical-screening.pythonaisolutions.com"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--client-secret",
        type=Path,
        default=DEFAULT_CLIENT_SECRET,
        help="Path to the desktop OAuth client secret JSON file.",
    )
    return parser.parse_args()


def load_credentials(client_secret: Path):
    flow = InstalledAppFlow.from_client_secrets_file(str(client_secret), scopes=SCOPES)
    creds = flow.run_local_server(port=0)
    return creds.id_token


def check_health(id_token: str) -> None:
    headers = {"Authorization": f"Bearer {id_token}"}
    resp = requests.get(f"{MLFLOW_BASE}/health", headers=headers, timeout=15, verify=False)
    resp.raise_for_status()


def list_experiments(id_token: str) -> list:
    os.environ["MLFLOW_TRACKING_TOKEN"] = id_token
    os.environ["MLFLOW_TRACKING_INSECURE_TLS"] = "1"
    mlflow.set_tracking_uri(MLFLOW_BASE)
    return list(mlflow.search_experiments())


def main() -> int:
    args = parse_args()
    if not args.client_secret.exists():
        print(f"Client secret file not found: {args.client_secret}", file=sys.stderr)
        return 1

    print("Opening browser to complete Google OAuth flow...")
    id_token = load_credentials(args.client_secret)
    print("✅ Received ID token.")

    print("Calling /health via oauth2-proxy…")
    check_health(id_token)
    print("✅ Health check succeeded.")

    print("Listing experiments through the MLflow client…")
    experiments = list_experiments(id_token)
    print(f"✅ Retrieved {len(experiments)} experiment(s).")
    for exp in experiments[:5]:
        print(f" - {exp.name} (ID: {exp.experiment_id}, location: {exp.artifact_location})")
    if len(experiments) > 5:
        print(f"   ...and {len(experiments) - 5} more.")

    print("\nDesktop OAuth flow completed successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
