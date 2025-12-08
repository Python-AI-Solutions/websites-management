# Cloudflare Migration Guide for pythonaisolutions.com

## Overview

This guide walks you through migrating your domain from Register365 to Cloudflare with minimal downtime (target: <30 seconds for websites, zero downtime for email).

## Migration Strategy

We'll use a phased approach:
1. **Phase 1:** Set up Cloudflare zone and DNS records (no impact)
2. **Phase 2:** Migrate domain DNS to Cloudflare (brief website downtime)
3. **Phase 3:** Verify all services are working
4. **Phase 4:** Migrate to Google Workspace email (when ready)

---

## Pre-Migration Checklist

### 1. Verify Current DNS Records at Register365

Before starting, document your current live DNS records:

```bash
# Run these commands to capture current DNS state
dig pythonaisolutions.com ANY +noall +answer > docs/current-dns-backup.txt
dig www.pythonaisolutions.com +noall +answer >> docs/current-dns-backup.txt
dig hih.pythonaisolutions.com +noall +answer >> docs/current-dns-backup.txt
# Add other subdomains as needed
```

Save this output - it's your safety net if you need to roll back.

### 2. Lower TTL Values (48 Hours Before Migration)

To minimize downtime, lower your TTL values at Register365:

1. Log into Register365 DNS management
2. Change all DNS record TTLs to 300 seconds (5 minutes)
3. Wait 48 hours for old TTL values to expire globally

**Why?** If something goes wrong, you can revert faster with low TTLs.

### 3. Update Placeholder Values in prod.tfvars

Edit `envs/prod.tfvars`:

```hcl
# Get Google site verification token:
# 1. Go to https://search.google.com/search-console
# 2. Add property for pythonaisolutions.com
# 3. Choose "HTML tag" method
# 4. Copy the content value from: <meta name="google-site-verification" content="YOUR_TOKEN">
google_site_verification = "YOUR_ACTUAL_TOKEN_HERE"
```

Update in the apex_records.txt array:
```hcl
{ value = "google-site-verification=YOUR_ACTUAL_TOKEN_HERE", ttl = 3600 },
```

### 4. GitHub Pages Records

**Note:** The existing GitHub Pages challenge records will become invalid after DNS migration. Plan to:
1. Remove these records before applying (comment them out)
2. Re-add the domain in GitHub after Cloudflare is active
3. GitHub will provide new challenge values
4. Add the new challenges to prod.tfvars and apply again

---

## Phase 1: Set Up Cloudflare (Zero Downtime)

### Step 1.1: Review and Apply Initial Configuration

```bash
# Review what will be created
pixi run plan-prod

# Review the plan carefully - you should see:
# - 1 cloudflare_zone resource (the domain)
# - ~17 DNS records
```

### Step 1.2: Comment Out GitHub Pages Challenges

Edit `envs/prod.tfvars` and comment out the GitHub challenges temporarily:

```hcl
  # "_github-pages-challenge-leej3" = {
  #   txt = [
  #     { value = "36f3cde9c7c302988b87bfb8b2965a", ttl = 86400 },
  #   ]
  # }
  #
  # "_github-pages-challenge-python-ai-solutions.presentations" = {
  #   txt = [
  #     { value = "36e88ec73472f3e0d4ee4d35ea3620", ttl = 86400 },
  #   ]
  # }
```

Re-run the plan:
```bash
pixi run plan-prod
```

### Step 1.3: Apply Cloudflare Configuration

```bash
# Create the zone and DNS records in Cloudflare
pixi run apply-prod

# IMPORTANT: Save the nameserver output
# You'll see something like:
# name_servers = [
#   "ada.ns.cloudflare.com",
#   "mark.ns.cloudflare.com",
# ]
```

**Save the Cloudflare nameservers** - you'll need them in Phase 2.

### Step 1.4: Verify DNS Records in Cloudflare

1. Log into Cloudflare dashboard: https://dash.cloudflare.com
2. Select pythonaisolutions.com zone
3. Go to DNS > Records
4. Verify all your records are present and correct
5. Check that values match what's in prod.tfvars

**Do NOT change nameservers yet!** Your domain is still pointing to Register365.

---

## Phase 2: DNS Migration (Brief Downtime)

### Step 2.1: Preparation (Daytime Recommended)

Choose a low-traffic time window. Have this guide and your terminal ready.

**Pre-flight checks:**
```bash
# Confirm current nameservers (should be Register365)
dig pythonaisolutions.com NS +short

# Confirm websites are reachable
curl -I https://pythonaisolutions.com
curl -I https://www.pythonaisolutions.com

# Test email (send yourself a test email)
```

### Step 2.2: Update Nameservers at Domain Registrar

Your domain registrar might be Register365 or somewhere else. You need to update the nameservers at the registrar level.

1. Log into your domain registrar (where you registered pythonaisolutions.com)
2. Find nameserver/DNS settings
3. Replace Register365 nameservers with Cloudflare nameservers from Step 1.3
4. Save changes

**Expected behavior:**
- Change is usually instant at registrar
- DNS propagation takes 5-30 minutes globally
- Some ISPs cache for longer (up to the old TTL)

### Step 2.3: Monitor Propagation

```bash
# Check nameserver propagation (run every 2-3 minutes)
dig pythonaisolutions.com NS +short

# When you see Cloudflare nameservers, test resolution:
dig pythonaisolutions.com A +short
dig www.pythonaisolutions.com CNAME +short
dig hih.pythonaisolutions.com A +short

# Test from multiple DNS servers:
dig @8.8.8.8 pythonaisolutions.com A +short  # Google DNS
dig @1.1.1.1 pythonaisolutions.com A +short  # Cloudflare DNS
```

### Step 2.4: Verify Websites

```bash
# Test all your websites
curl -I https://pythonaisolutions.com
curl -I https://www.pythonaisolutions.com
curl -I https://hih.pythonaisolutions.com
curl -I https://cervical-screening.pythonaisolutions.com
curl -I https://osm.pythonaisolutions.com

# Or visit them in your browser
```

**If something is broken:**
1. Check Cloudflare DNS records
2. Use `pixi run plan-prod` to see if config drifted
3. Update prod.tfvars and `pixi run apply-prod` to fix

### Step 2.5: Verify Email (Google Workspace)

Your email should continue working because:
- Google Workspace MX records are managed by Google directly, not in DNS
- Your existing Google Workspace setup doesn't depend on the DNS records we removed

Test:
```bash
# Check MX records
dig pythonaisolutions.com MX +short

# Send test email to yourself
# Reply to a recent email
# Send a new email outbound
```

---

## Phase 3: Re-enable GitHub Pages (After DNS Migration)

### Step 3.1: Remove Domain from GitHub (if currently configured)

1. Go to your GitHub repository settings
2. Pages > Custom domain
3. Remove pythonaisolutions.com
4. Remove any subdomain custom domains (www, presentations, etc.)

### Step 3.2: Re-add Domain with New DNS

1. Go to your GitHub repository for www subdomain
2. Settings > Pages > Custom domain
3. Enter: `www.pythonaisolutions.com`
4. GitHub will verify the CNAME record (should work immediately via Cloudflare)
5. GitHub will provide a new challenge TXT record

Example output from GitHub:
```
Add this TXT record to your DNS:
_github-pages-challenge-leej3.pythonaisolutions.com
Value: abc123newvalue456
```

### Step 3.3: Add New Challenge to Cloudflare

Update `envs/prod.tfvars`:

```hcl
  "_github-pages-challenge-leej3" = {
    txt = [
      { value = "NEW_VALUE_FROM_GITHUB", ttl = 86400 },
    ]
  }
```

Apply:
```bash
pixi run plan-prod
pixi run apply-prod
```

### Step 3.4: Complete GitHub Verification

1. Wait 30 seconds for DNS propagation
2. Click "Verify" in GitHub Pages settings
3. Enable HTTPS (recommended)

Repeat for other GitHub Pages domains:
- presentations.pythonaisolutions.com (if using GitHub Pages)

---

## Phase 4: Enable Google Workspace DNS Records (Future)

When you're ready to fully manage Google Workspace via IaC:

### Step 4.1: Get DKIM Records from Google

1. Log into Google Workspace Admin: https://admin.google.com
2. Apps > Google Workspace > Gmail > Authenticate email
3. Generate new DKIM key if needed
4. Copy the DKIM record details

### Step 4.2: Update prod.tfvars

```hcl
gmail_enabled = true

# Add DKIM records
dkim_records = [
  {
    selector = "google"  # or the selector Google provides
    value    = "v=DKIM1; k=rsa; p=YOUR_LONG_PUBLIC_KEY_HERE"
    ttl      = 3600
  }
]

# Optional: update DMARC settings
dmarc_policy = "quarantine"  # or "reject" when confident
dmarc_rua    = "mailto:dmarc@pythonaisolutions.com"
```

### Step 4.3: Remove Manual SPF Record

Since the google-workspace-email module now manages SPF, remove it from apex_records:

```hcl
apex_records = {
  a = [
    # ... keep A records ...
  ]

  txt = [
    { value = "google-site-verification=YOUR_TOKEN", ttl = 3600 },
    # Remove SPF - now managed by gmail module:
    # { value = "v=spf1 include:_spf.google.com ~all", ttl = 3600 },
  ]
}
```

### Step 4.4: Apply and Verify

```bash
pixi run plan-prod  # Verify MX, SPF, DKIM, DMARC will be created
pixi run apply-prod

# Verify email records
dig pythonaisolutions.com MX +short
dig pythonaisolutions.com TXT +short | grep spf
dig google._domainkey.pythonaisolutions.com TXT +short
dig _dmarc.pythonaisolutions.com TXT +short

# Test email in/out
```

### Step 4.5: Verify in Google Workspace

1. Go to Google Admin > Apps > Gmail > Authenticate email
2. Verify all records show as "Authenticated"
3. Send test emails and check headers for DKIM/SPF pass

---

## Rollback Plan

If something goes catastrophically wrong:

### Emergency Rollback to Register365

1. Log into your domain registrar
2. Change nameservers back to Register365 nameservers
3. Wait 5-30 minutes for propagation
4. Verify services are restored

### Post-Rollback

1. Review what went wrong
2. Fix issues in prod.tfvars
3. Test with `pixi run plan-prod`
4. Try migration again when ready

---

## Post-Migration Checklist

After successful migration:

- [ ] All websites are accessible and working
- [ ] Email sending works (test outbound)
- [ ] Email receiving works (test inbound)
- [ ] GitHub Pages domains verified and working
- [ ] SSL/TLS certificates valid (GitHub Pages HTTPS, Cloudflare SSL)
- [ ] Monitor email deliverability for 48 hours
- [ ] Update any documentation with new DNS management process
- [ ] Increase TTL values back to normal (3600-86400)
- [ ] Cancel Register365 DNS services (after 30-day safety period)

---

## Monitoring and Troubleshooting

### DNS Resolution Issues

```bash
# Check what Cloudflare is serving
dig @1.1.1.1 pythonaisolutions.com ANY +short

# Check global propagation
# Visit: https://www.whatsmydns.net/#A/pythonaisolutions.com
```

### Email Issues

```bash
# Verify email DNS records
dig pythonaisolutions.com MX +short
dig pythonaisolutions.com TXT +short | grep spf
dig _dmarc.pythonaisolutions.com TXT +short

# Check email headers of received messages for SPF/DKIM status
```

### Website Issues

1. Check Cloudflare DNS records in dashboard
2. Verify A/CNAME records match prod.tfvars
3. Check Cloudflare proxy status (orange cloud vs gray cloud)
4. Review Cloudflare SSL/TLS settings

### Getting Help

- Cloudflare Community: https://community.cloudflare.com/
- Cloudflare Support: https://dash.cloudflare.com (if you have a paid plan)
- Check Cloudflare Status: https://www.cloudflarestatus.com/

---

## Timeline Estimate

| Phase | Duration | Downtime |
|-------|----------|----------|
| Pre-migration prep | 30 minutes | None |
| TTL reduction wait | 48 hours | None |
| Phase 1: Cloudflare setup | 15 minutes | None |
| Phase 2: NS migration | 15-30 minutes | 0-30 seconds* |
| Phase 3: GitHub Pages | 15 minutes | Brief (during verification) |
| Phase 4: Google Workspace | 30 minutes | None** |

\* Downtime depends on DNS propagation speed
\*\* Email continues to work; you're just adding DNS records

**Total active work time:** ~2 hours
**Total calendar time:** 48-72 hours (due to TTL waiting period)

---

## Notes

- **Keep Register365 active** for at least 30 days after migration as a safety net
- **Monitor email deliverability** closely for the first week
- **Don't delete this repo** - it's now your source of truth for DNS
- **Commit changes** to git regularly during migration
- **Take screenshots** of working configurations at each phase
