# Removed DNS Records - 2025-10-28

This document tracks DNS records that were removed during the migration to Cloudflare.

## Register365 Email Infrastructure (Obsolete)

These records were removed because you switched to Google Workspace:

### Subdomains Removed:
- **autoconfig.pythonaisolutions.com** → `autoconfig.register365.com`
  - Used for email client auto-configuration with Register365

- **imap.pythonaisolutions.com** → `imap.reg365.net`
  - Old IMAP server endpoint

- **pop3.pythonaisolutions.com** → `pop3.reg365.net`
  - Old POP3 server endpoint

- **cpanel.pythonaisolutions.com** → NS delegation to Register365
  - Values: `ns0.reg365.net`, `ns1.reg365.net`, `ns2.reg365.net`
  - Old hosting control panel subdomain delegation

### Apex Records Removed:
- **_autodiscover._tcp SRV record** → `autodiscover.reg365.net`
  - Service: `_autodiscover`, Proto: `_tcp`
  - Priority: 0, Weight: 0, Port: 443
  - Used for Outlook/Exchange email client auto-discovery with Register365

- **MS verification TXT record** → `MS=ms9071387??`
  - Microsoft domain verification (appeared to be incomplete/uncertain based on `??`)
  - If you need Microsoft services in the future, they will provide a new verification string

## Impact
All these records were specific to Register365 email hosting and are no longer needed with Google Workspace. Email services are now handled through Google's infrastructure.

## Note on Current Configuration
- SPF record (`v=spf1 include:_spf.google.com ~all`) is currently kept in manual TXT records
- When you set `gmail_enabled = true`, this will be managed by the google-workspace-email module
- GitHub Pages challenge records are still present but will need regeneration after DNS migration
