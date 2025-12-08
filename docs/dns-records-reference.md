# DNS Records Reference

This reference explains how the current registrar records map into the OpenTofu variables, and where you should drop missing data extracted from `current-settings/`.

## Apex (`apex_records`)
| Type | Target | Notes |
|------|--------|-------|
| A    | `185.199.108.153` |
| A    | `185.199.109.153` |
| A    | `185.199.110.153` |
| A    | `185.199.111.153` | GitHub Pages anycast addresses |
| TXT  | `google-site-verification=...` | Populate from registrar |
| TXT  | `MS=...` | Provide the Microsoft verification string verbatim |
| TXT  | `v=spf1 include:_spf.google.com ~all` | Managed by the Google module but mirrored here for clarity |
| SRV  | `_autodiscover._tcp` → `autodiscover.<host>` | Replace `autodiscover.TODO-update` with the full hostname |

> Tip: Use `@` (apex) for the SRV record `name` so Outlook autodiscover continues to resolve.

## Subdomains (`subdomain_records`)
| Host | Type(s) | Current target | Action |
|------|---------|----------------|--------|
| `www` | CNAME | `leej3.github.io` | Leave as-is for GitHub Pages |
| `presentations` | CNAME | `hih-presentations...` | Replace `hih-presentation.TODO-update` with the exact value |
| `cervical-screening` | A | `104.198.164.116` | Confirm this IP during migration |
| `staging.cervical-screening` | A | `104.198.164.116` | Adjust if staging diverges |
| `mlflow.cervical-screening` | A | `104.198.164.116` | Adjust as needed |
| `hih` | A | `35.194.17.231` | — |
| `osm` | A | `18.214.163.6` | — |
| `osm-dashboard` | A | `18.214.163.6` | — |
| `autoconfig` | CNAME | `autoconfig.*` | Fill the full hostname (usually `autoconfig.reg365.net`) |
| `imap` | CNAME | `imap.reg365.net` | — |
| `pop3` | CNAME | `pop3.reg365.net` | — |
| `cpanel` | NS x3 | `ns0/1/2.reg365.net` | Retain if you still delegate this subdomain to the registrar |
| `_github-pages-challenge-*` | TXT | `36f3cde9c7c302...`, `36e88ec73472f3...` | Rename keys to the exact challenge hostnames and paste full tokens |

When you discover the precise values, edit `envs/prod.tfvars` and re-run `pixi run plan-prod` to confirm no drift remains. Keep staging in sync if you rely on those hostnames for testing.

## Adding new records
Add new entries to the relevant map, following the existing structure. Examples:

```hcl
subdomain_records = merge(var.subdomain_records, {
  "api" = {
    a = [{ value = "203.0.113.10", proxied = true }]
  }
  "status" = {
    cname = [{ value = "statuspage.io", proxied = false }]
  }
})
```

Re-run `pixi run plan:<workspace>` to review before applying.
