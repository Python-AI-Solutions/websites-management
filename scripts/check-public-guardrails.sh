#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/check-public-guardrails.sh [--staged|--tracked|--all|--verify-ignore]

Checks public-repo leak guardrails for sensitive local artifacts.

  --staged         Check files currently staged for commit. Default.
  --tracked        Check all tracked files.
  --verify-ignore  Verify representative local artifact paths are ignored.
  --all            Run --tracked, --staged, and --verify-ignore.
USAGE
}

mode="${1:---staged}"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

failures=0

is_allowed_path() {
  case "$1" in
    .env.example|*/.env.example|.env.sample|*/.env.sample|.env.template|*/.env.template)
      return 0
      ;;
    envs/prod.tfvars|envs/staging.tfvars)
      return 0
      ;;
    k8s/aws/wireguard-peers.auto.tfvars.json)
      return 0
      ;;
  esac

  return 1
}

blocked_reason_for_path() {
  if is_allowed_path "$1"; then
    return 1
  fi

  case "$1" in
    .env|*/.env|.env.*|*/.env.*)
      printf '%s' "environment file"
      ;;
    .dev.vars|*/.dev.vars|.dev.vars.*|*/.dev.vars.*)
      printf '%s' "Cloudflare local vars"
      ;;
    terraform.tfvars|*/terraform.tfvars|terraform.tfvars.json|*/terraform.tfvars.json|*.tfvars|*.tfvars.json|*.auto.tfvars|*.auto.tfvars.json)
      printf '%s' "local Terraform/OpenTofu variables"
      ;;
    *.tfstate|*.tfstate.*)
      printf '%s' "Terraform/OpenTofu state"
      ;;
    tfplan|*/tfplan|tfplan-*|*/tfplan-*|*.tfplan|*.tfplan.*)
      printf '%s' "Terraform/OpenTofu plan output"
      ;;
    .terraform/*|*/.terraform/*|.terraform.d/*|*/.terraform.d/*|.tofu-cache/*|*/.tofu-cache/*)
      printf '%s' "Terraform/OpenTofu working directory"
      ;;
    kubeconfig|*/kubeconfig|kubeconfig.*|*/kubeconfig.*|*.kubeconfig|*.kubeconfig.*)
      printf '%s' "Kubernetes kubeconfig"
      ;;
    k8s/tmp-*|k8s/*/tmp-*)
      printf '%s' "temporary Kubernetes manifest"
      ;;
    .wrangler/*|*/.wrangler/*)
      printf '%s' "Wrangler local cache"
      ;;
    supabase/.temp/*|*/supabase/.temp/*)
      printf '%s' "Supabase local temp data"
      ;;
    test-results/*|*/test-results/*|playwright-report/*|*/playwright-report/*)
      printf '%s' "local test artifact"
      ;;
    *.pem|*.key|id_rsa*|*/id_rsa*|id_ed25519*|*/id_ed25519*)
      printf '%s' "private key material"
      ;;
    *)
      return 1
      ;;
  esac
}

check_path_stream() {
  scope="$1"
  while IFS= read -r -d '' path; do
    reason="$(blocked_reason_for_path "$path" || true)"
    if [ -n "$reason" ]; then
      if [ "$failures" -eq 0 ]; then
        printf 'Public repo guardrail check failed.\n' >&2
      fi
      printf '  %s: %s (%s)\n' "$scope" "$path" "$reason" >&2
      failures=1
    fi
  done
}

check_staged() {
  check_path_stream "staged" < <(git diff --cached --name-only --diff-filter=ACMR -z)
}

check_tracked() {
  check_path_stream "tracked" < <(
    while IFS= read -r -d '' path; do
      [ -e "$path" ] && printf '%s\0' "$path"
    done < <(git ls-files -z)
  )
}

verify_ignore() {
  required_ignored=(
    ".env"
    ".env.local"
    "sites/example/.env.local"
    ".dev.vars"
    "sites/example/.dev.vars.local"
    "k8s/terraform.tfvars"
    "k8s/terraform.tfvars.json"
    "k8s/aws/local.auto.tfvars"
    "root/secrets.tfvars"
    "k8s/kubeconfig"
    "k8s/kubeconfig.yaml"
    "k8s/tmp-encryption-config.yaml"
    "k8s/tmp-audit-policy.yml"
    "root/terraform.tfstate"
    "root/terraform.tfstate.backup"
    "root/tfplan"
    "root/tfplan-prod"
    "root/plan.tfplan"
    ".wrangler/state.json"
    "sites/example/.wrangler/state.json"
    "sites/example/supabase/.temp/project-ref"
    "test-results/output.json"
    "sites/example/test-results/output.json"
  )

  required_allowed=(
    ".env.example"
    ".env.sample"
    ".env.template"
    "envs/prod.tfvars"
    "envs/staging.tfvars"
    "k8s/aws/wireguard-peers.auto.tfvars.json"
  )

  for path in "${required_ignored[@]}"; do
    if ! git check-ignore --no-index -q -- "$path"; then
      if [ "$failures" -eq 0 ]; then
        printf 'Public repo guardrail check failed.\n' >&2
      fi
      printf '  ignore-missing: %s\n' "$path" >&2
      failures=1
    fi
  done

  for path in "${required_allowed[@]}"; do
    if git check-ignore --no-index -q -- "$path"; then
      if [ "$failures" -eq 0 ]; then
        printf 'Public repo guardrail check failed.\n' >&2
      fi
      printf '  should-not-ignore: %s\n' "$path" >&2
      failures=1
    fi
  done
}

case "$mode" in
  --staged)
    check_staged
    ;;
  --tracked)
    check_tracked
    ;;
  --verify-ignore)
    verify_ignore
    ;;
  --all)
    check_tracked
    check_staged
    verify_ignore
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ "$failures" -ne 0 ]; then
  printf '\nRemove these files from the index or update the allowlist only after review.\n' >&2
  exit 1
fi

printf 'Public repo guardrail check passed (%s).\n' "$mode"
