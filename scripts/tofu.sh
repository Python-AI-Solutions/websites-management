#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${TOFU_IMAGE_NAME:-cloudflare-tofu}"
CACHE_DIR="${REPO_ROOT}/.tofu-cache"

source "${REPO_ROOT}/scripts/load-env.sh"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install Docker Desktop or CLI before running this command." >&2
  exit 1
fi

if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  docker build -t "${IMAGE_NAME}" "${REPO_ROOT}/docker"
fi

mkdir -p "${CACHE_DIR}"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <tofu command | tflint>" >&2
  exit 1
fi

COMMAND="$1"
shift || true

ENV_VARS=(
  CLOUDFLARE_API_TOKEN
  CLOUDFLARE_ACCOUNT_ID
  TF_VAR_zone_name
  TF_VAR_dmarc_rua
  TF_VAR_dmarc_ruf
  TF_VAR_dmarc_policy
  TF_VAR_spf_txt
)

ENV_ARGS=()
for var in "${ENV_VARS[@]}"; do
  value="${!var-}"
  if [[ -n "${value}" ]]; then
    ENV_ARGS+=(--env "${var}=${value}")
  fi
done

docker_run() {
  local workdir="$1"
  shift
  docker run --rm -i \
    "${ENV_ARGS[@]}" \
    -v "${REPO_ROOT}:/workspace" \
    -v "${CACHE_DIR}:/tf-cache" \
    --workdir "${workdir}" \
    "${IMAGE_NAME}" "$@"
}

case "${COMMAND}" in
  shell)
    docker_run /workspace bash
    ;;
  tflint)
    docker_run /workspace tflint "$@"
    ;;
  *)
    docker_run /workspace/root tofu "${COMMAND}" "$@"
    ;;
esac
