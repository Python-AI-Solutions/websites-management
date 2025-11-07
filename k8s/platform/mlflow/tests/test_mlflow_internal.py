#!/usr/bin/env python3
"""
Smoke-test the MLflow deployment inside the cluster.

The script:
1. Finds the running MLflow pod.
2. Runs a health check against http://localhost:5000/health from inside the pod.
3. Executes a short Python snippet in the pod that creates/logs to a throwaway
   experiment via the MLflow tracking API (no oauth needed for in-cluster calls).

Prerequisites: kubectl context pointing at the target cluster and python requests installed
               on the local machine (bundled in the base environment).
"""

from __future__ import annotations

import subprocess
import sys

NAMESPACE = "mlflow"
EXPERIMENT_NAME = "platform-smoke-test"


def _run(cmd: list[str], *, capture_output: bool = True, check: bool = True, text: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=capture_output, check=check, text=text)


def get_mlflow_pod() -> str:
    result = _run(
        [
            "kubectl",
            "get",
            "pods",
            "-n",
            NAMESPACE,
            "-l",
            "app=mlflow",
            "-o",
            "jsonpath={.items[0].metadata.name}",
        ]
    )
    pod_name = result.stdout.strip()
    if not pod_name:
        raise RuntimeError("Could not find an mlflow pod in namespace 'mlflow'")
    return pod_name


def check_health(pod_name: str) -> None:
    health_script = """
import urllib.request
with urllib.request.urlopen('http://localhost:5000/health', timeout=5) as resp:
    body = resp.read().decode()
    print(body)
"""
    _run(
        [
            "kubectl",
            "exec",
            "-i",
            "-n",
            NAMESPACE,
            pod_name,
            "--",
            "python",
            "-c",
            health_script,
        ]
    )


def exercise_tracking_api(pod_name: str) -> None:
    mlflow_script = f"""
import time
import requests

BASE = "http://localhost:5000"
HEADERS = {{"Host": "mlflow.cervical-screening.pythonaisolutions.com"}}
name = "{EXPERIMENT_NAME}"

search_resp = requests.post(
    f"{{BASE}}/api/2.0/mlflow/experiments/search",
    headers=HEADERS,
    json={{"max_results": 200}},
    timeout=10,
)
search_resp.raise_for_status()
experiments = search_resp.json().get("experiments", [])
target = next((exp for exp in experiments if exp.get("name") == name), None)

if target is None:
    create_resp = requests.post(
        f"{{BASE}}/api/2.0/mlflow/experiments/create",
        headers=HEADERS,
        json={{"name": name}},
        timeout=10,
    )
    create_resp.raise_for_status()
    experiment_id = create_resp.json()["experiment_id"]
else:
    experiment_id = target["experiment_id"]

run_payload = {{
    "experiment_id": experiment_id,
    "start_time": int(time.time() * 1000),
    "tags": [{{"key": "platform", "value": "terraform"}}],
}}
run_resp = requests.post(
    f"{{BASE}}/api/2.0/mlflow/runs/create",
    headers=HEADERS,
    json=run_payload,
    timeout=10,
)
run_resp.raise_for_status()
run_id = run_resp.json()["run"]["info"]["run_id"]

metric_payload = {{
    "run_id": run_id,
    "key": "smoke_metric",
    "value": 1.0,
    "timestamp": int(time.time() * 1000),
    "step": 0,
}}
metric_resp = requests.post(
    f"{{BASE}}/api/2.0/mlflow/runs/log-metric",
    headers=HEADERS,
    json=metric_payload,
    timeout=10,
)
metric_resp.raise_for_status()
print("MLflow REST smoke test completed")
"""
    _run(
        [
            "kubectl",
            "exec",
            "-i",
            "-n",
            NAMESPACE,
            pod_name,
            "--",
            "python",
            "-c",
            mlflow_script,
        ]
    )


def main() -> int:
    try:
        pod = get_mlflow_pod()
        print(f"Using mlflow pod: {pod}")
        print("Running /health check...")
        check_health(pod)
        print("Health check succeeded.")
        print("Exercising MLflow tracking API...")
        exercise_tracking_api(pod)
        print("Tracking test succeeded.")
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.stderr or "")
        print(f"Command failed: {' '.join(exc.cmd)}", file=sys.stderr)
        return exc.returncode or 1
    except Exception as err:  # noqa: BLE001
        print(f"Error: {err}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
