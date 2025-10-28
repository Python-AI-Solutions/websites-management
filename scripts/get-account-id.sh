#!/usr/bin/env bash
# Get Cloudflare account ID using the API token

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/load-env.sh"

if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN is not set" >&2
  exit 1
fi

curl -s -X GET "https://api.cloudflare.com/client/v4/accounts" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" | \
  python -c '
import sys, json
data = json.load(sys.stdin)
if not data["success"]:
    print("Error:", data["errors"], file=sys.stderr)
    sys.exit(1)
accounts = data["result"]
print("Found {} account(s):".format(len(accounts)))
for acc in accounts:
    acc_name = acc["name"]
    acc_id = acc["id"]
    print("  - {}: {}".format(acc_name, acc_id))
if len(accounts) == 1:
    acc_id = accounts[0]["id"]
    print("\nYour account ID is: {}".format(acc_id))
    print("Add this to your .env file:")
    print("CLOUDFLARE_ACCOUNT_ID={}".format(acc_id))
'
