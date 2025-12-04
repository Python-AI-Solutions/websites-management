# Google Workspace DNS Checklist

The `modules/google-workspace-email` module provisions everything Gmail needs to accept and deliver mail for `example-organization.com`. Work through the steps below when migrating the zone into Cloudflare.

## 1. Gather workspace values
1. Sign in to the [Google Admin console](https://admin.google.com/) with a super-admin account.
2. Navigate to **Apps → Google Workspace → Gmail → Authenticate Email**.
3. Copy the **Google site verification** token (under _Verify domain_). Paste the string _without_ the `google-site-verification=` prefix into:
   ```hcl
   google_site_verification = "YOUR_TOKEN"
   ```
   inside `envs/prod.tfvars` (and staging if needed).

## 2. Confirm MX records
The module writes the standard Gmail MX set:

| Priority | Host                            |
|----------|---------------------------------|
| 1        | `ASPMX.L.GOOGLE.COM.`           |
| 5        | `ALT1.ASPMX.L.GOOGLE.COM.`      |
| 5        | `ALT2.ASPMX.L.GOOGLE.COM.`      |
| 10       | `ALT3.ASPMX.L.GOOGLE.COM.`      |
| 10       | `ALT4.ASPMX.L.GOOGLE.COM.`      |

If Google changes these values, update `modules/google-workspace-email/main.tf` accordingly, then re-run `pixi run plan:<workspace>`.

## 3. SPF policy
The default SPF string (`v=spf1 include:_spf.google.com ~all`) matches Google’s recommended configuration. If you relay mail through additional services (e.g. SendGrid), merge them into `TF_VAR_spf_txt` (either in `.env` or the tfvars files).

## 4. DMARC policy
Update the DMARC reporting addresses before applying:

```hcl
dmarc_rua = "mailto:dmarc@example.com"  # Replace with your domain
dmarc_ruf = "mailto:dmarc-forensic@example.com" # optional - Replace with your domain
dmarc_policy = "quarantine" # or none/reject
dmarc_pct = 100
```

If you change any of these values later, re-run `pixi run plan:<workspace>` and apply.

## 5. DKIM selectors
1. In the Admin console, under **Authenticate Email**, select each domain and click **Generate new record** (or **View setup** if you already have selectors).
2. For every selector, add an entry to `dkim_records`:
   ```hcl
   dkim_records = [
     {
       selector = "google"
       value    = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAA..." # paste the full value
       ttl      = 3600
     },
   ]
   ```
3. After applying, return to the Admin console and click **Start authentication** for each selector so Google begins signing outbound mail.

## 6. Post-migration validation
1. Run `pixi run plan-prod` and inspect `root/tfplan-prod.txt` to confirm Google-related records will be created as expected.
2. Apply the changes (`pixi run apply-prod`) once Cloudflare is authoritative for the zone.
3. Use [Google’s CheckMX tool](https://toolbox.googleapps.com/apps/checkmx/) to verify MX, SPF, DKIM, and DMARC are all passing.
4. Send test emails to confirm delivery in both directions.
