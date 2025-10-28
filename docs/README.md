# Documentation Index

## Migration Documents

### [Migration Guide](migration-guide.md) - **START HERE**
Comprehensive step-by-step guide for migrating from Register365 to Cloudflare.
- Phase 1: Set up Cloudflare (zero downtime)
- Phase 2: DNS migration (brief downtime)
- Phase 3: Re-enable GitHub Pages
- Phase 4: Enable Google Workspace DNS (optional)

**Use this for:** First-time migration planning and execution.

### [Migration Checklist](migration-checklist.md)
Quick reference checklist for the migration process. Print this or keep it open during migration.

**Use this for:** Day-of migration task tracking.

## Reference Documents

### [DNS Records Review](dns-records-review.md)
Analysis of current DNS records with recommendations on what to keep, update, or remove.

**Use this for:** Understanding your current DNS configuration.

### [Removed DNS Records](removed-dns-records.md)
Archive of DNS records that were removed during cleanup (mostly obsolete Register365 email infrastructure).

**Use this for:** Historical reference if you need to verify what was removed.

### [Google Workspace Setup](google-workspace-setup.md)
Detailed guide for enabling Google Workspace email management via the IaC module (Phase 4).

**Use this for:** When you're ready to manage Gmail DNS records via OpenTofu.

### [DNS Records Reference](dns-records-reference.md)
Technical reference for the DNS record structure and formats used in `prod.tfvars`.

**Use this for:** Understanding how to add/modify DNS records in the tfvars files.

## Quick Links

### Before Migration
1. Read [Migration Guide](migration-guide.md)
2. Review [DNS Records Review](dns-records-review.md)
3. Update placeholders in `envs/prod.tfvars`
4. Run through [Migration Checklist](migration-checklist.md)

### During Migration
- Follow [Migration Guide](migration-guide.md) Phase 1-3
- Use `pixi run verify-dns` to check DNS propagation
- Check off items in [Migration Checklist](migration-checklist.md)

### After Migration
- Complete [Migration Checklist](migration-checklist.md) post-migration items
- (Optional) Set up [Google Workspace DNS](google-workspace-setup.md)

## Scripts

Located in `../scripts/`:
- `verify-dns.sh` - Check DNS records and website accessibility (run via `pixi run verify-dns`)
- `get-account-id.sh` - Retrieve Cloudflare account ID from API
- `load-env.sh` - Load environment variables from `.env` file

## Support

If you encounter issues during migration:
1. Check the Troubleshooting section in [Migration Guide](migration-guide.md)
2. Review Cloudflare DNS dashboard for record status
3. Use `pixi run verify-dns` to diagnose DNS issues
4. Check [Removed DNS Records](removed-dns-records.md) if something is missing
