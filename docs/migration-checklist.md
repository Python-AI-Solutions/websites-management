# Migration Checklist

Quick reference for the Cloudflare migration. See `migration-guide.md` for detailed instructions.

## 48 Hours Before Migration

- [ ] Backup current DNS records: `dig pythonaisolutions.com ANY +noall +answer > docs/current-dns-backup.txt`
- [ ] Lower TTLs at Register365 to 300 seconds
- [ ] Set calendar reminder for migration window
- [ ] Update `google_site_verification` token in `envs/prod.tfvars`

## Pre-Migration (Day Of)

- [ ] Comment out GitHub challenge records in `envs/prod.tfvars`
- [ ] Run `pixi run plan-prod` and review
- [ ] Run `pixi run apply-prod` to create Cloudflare zone
- [ ] Save Cloudflare nameservers from output
- [ ] Verify all DNS records in Cloudflare dashboard
- [ ] Test current services are working (websites, email)

## Migration Window

- [ ] Update nameservers at domain registrar to Cloudflare nameservers
- [ ] Monitor propagation: `dig pythonaisolutions.com NS +short`
- [ ] Test websites when propagation complete
- [ ] Test email send/receive
- [ ] Verify all subdomains working

## Post-Migration (Same Day)

- [ ] Remove www from GitHub Pages settings
- [ ] Re-add www to GitHub Pages (get new challenge)
- [ ] Update `envs/prod.tfvars` with new GitHub challenge
- [ ] Run `pixi run apply-prod`
- [ ] Verify GitHub Pages domain in GitHub settings
- [ ] Enable HTTPS on GitHub Pages

## Day 1-3 After Migration

- [ ] Monitor email deliverability
- [ ] Check all services daily
- [ ] Review Cloudflare analytics
- [ ] Verify HTTPS certificates valid everywhere

## Week 1-4 After Migration

- [ ] Increase TTLs back to normal (3600-86400)
- [ ] Update internal documentation
- [ ] Plan Gmail DNS migration (Phase 4) if desired
- [ ] Keep Register365 DNS active as safety net

## 30+ Days After Migration

- [ ] Cancel Register365 DNS services (if everything stable)
- [ ] Archive this checklist with migration date and notes

---

## Emergency Contacts

- Domain Registrar: _____________________
- Cloudflare Account Email: _____________________
- Google Workspace Admin: _____________________

## Rollback Plan

If critical failure:
1. Change nameservers back to Register365
2. Wait 5-30 minutes
3. Verify services restored
4. Document what went wrong
5. Fix and retry later

---

## Migration Date: ____________

Notes:
