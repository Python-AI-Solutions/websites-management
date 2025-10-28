#!/usr/bin/env bash
# DNS Verification Script for Migration
# Run this before and after migration to verify DNS records

set -euo pipefail

DOMAIN="pythonaisolutions.com"
SUBDOMAINS=(
  "www"
  "presentations"
  "cervical-screening"
  "staging.cervical-screening"
  "mlflow.cervical-screening"
  "hih"
  "osm"
  "osm-dashboard"
)

echo "====================================="
echo "DNS Verification for ${DOMAIN}"
echo "====================================="
echo ""

# Check nameservers
echo "1. Nameservers:"
dig ${DOMAIN} NS +short
echo ""

# Check apex A records
echo "2. Apex A Records:"
dig ${DOMAIN} A +short
echo ""

# Check apex TXT records
echo "3. Apex TXT Records:"
dig ${DOMAIN} TXT +short
echo ""

# Check MX records
echo "4. MX Records:"
dig ${DOMAIN} MX +short
echo ""

# Check each subdomain
echo "5. Subdomain Records:"
for subdomain in "${SUBDOMAINS[@]}"; do
  fqdn="${subdomain}.${DOMAIN}"
  echo "   ${fqdn}:"

  # Try A record first
  a_records=$(dig ${fqdn} A +short 2>/dev/null)
  if [ -n "$a_records" ]; then
    echo "      A: $a_records"
  fi

  # Try CNAME
  cname_records=$(dig ${fqdn} CNAME +short 2>/dev/null)
  if [ -n "$cname_records" ]; then
    echo "      CNAME: $cname_records"
  fi

  if [ -z "$a_records" ] && [ -z "$cname_records" ]; then
    echo "      No records found"
  fi
done

echo ""
echo "====================================="
echo "Global Propagation Check"
echo "====================================="
echo "Visit: https://www.whatsmydns.net/#A/${DOMAIN}"
echo ""

# Test from multiple DNS servers
echo "6. DNS Server Comparison:"
echo "   Google DNS (8.8.8.8):"
echo "      $(dig @8.8.8.8 ${DOMAIN} A +short | head -1)"
echo "   Cloudflare DNS (1.1.1.1):"
echo "      $(dig @1.1.1.1 ${DOMAIN} A +short | head -1)"
echo "   Quad9 DNS (9.9.9.9):"
echo "      $(dig @9.9.9.9 ${DOMAIN} A +short | head -1)"
echo ""

echo "====================================="
echo "Website Accessibility Check"
echo "====================================="
for subdomain in "www" "hih" "osm"; do
  fqdn="${subdomain}.${DOMAIN}"
  if curl -Is "https://${fqdn}" --connect-timeout 5 >/dev/null 2>&1; then
    echo "   ✓ https://${fqdn} is accessible"
  else
    echo "   ✗ https://${fqdn} is NOT accessible"
  fi
done

# Check apex
if curl -Is "https://${DOMAIN}" --connect-timeout 5 >/dev/null 2>&1; then
  echo "   ✓ https://${DOMAIN} is accessible"
else
  echo "   ✗ https://${DOMAIN} is NOT accessible"
fi

echo ""
echo "====================================="
echo "Verification complete!"
echo "====================================="
