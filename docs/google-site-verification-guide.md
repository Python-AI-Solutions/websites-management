# Google Site Verification Guide

## Option 1: DNS TXT Record Method (Recommended for This Setup)

This is the easiest method since you're already managing DNS records with OpenTofu.

### Step 1: Access Google Search Console

1. Go to [Google Search Console](https://search.google.com/search-console)
2. Sign in with your Google account (preferably your Google Workspace admin account)

### Step 2: Add Your Property

1. Click **Add Property** (or the dropdown in the top left if you have existing properties)
2. Choose **Domain** (not URL prefix)
3. Enter: `pythonaisolutions.com`
4. Click **Continue**

### Step 3: Get the DNS TXT Record

Google will show you a verification screen with:

```
TXT record:
google-site-verification=abc123XYZ456...
```

The format will look something like:
```
google-site-verification=rXOxyZounnZasA3NiEM5CRii-F8cPFnrzYsaGwwPM9A
```

Copy **just the token part** after the `=` sign.

Example:
- Full record: `google-site-verification=rXOxyZounnZasA3NiEM5CRii-F8cPFnrzYsaGwwPM9A`
- Token to copy: `rXOxyZounnZasA3NiEM5CRii-F8cPFnrzYsaGwwPM9A`

### Step 4: Add to prod.tfvars

Edit `envs/prod.tfvars`:

```hcl
google_site_verification = "rXOxyZounnZasA3NiEM5CRii-F8cPFnrzYsaGwwPM9A"
```

And update the TXT record in `apex_records`:

```hcl
apex_records = {
  # ... other records ...

  txt = [
    { value = "google-site-verification=rXOxyZounnZasA3NiEM5CRii-F8cPFnrzYsaGwwPM9A", ttl = 3600 },
    { value = "v=spf1 include:_spf.google.com ~all", ttl = 3600 },
  ]
}
```

### Step 5: Apply the DNS Record

```bash
pixi run plan-prod   # Verify the TXT record will be created
pixi run apply-prod  # Create the record
```

### Step 6: Verify in Google Search Console

1. Wait 1-2 minutes for DNS propagation
2. Return to the Google Search Console verification screen
3. Click **Verify**

If verification succeeds, you'll see:
```
✓ Ownership verified
```

### Troubleshooting

If verification fails:

1. **Check DNS propagation:**
   ```bash
   dig pythonaisolutions.com TXT +short | grep google-site-verification
   ```

   Should show:
   ```
   "google-site-verification=YOUR_TOKEN"
   ```

2. **Wait longer:** DNS propagation can take up to 48 hours (usually 5-10 minutes)

3. **Verify exact token:** Make sure there are no extra spaces or characters

4. **Check from multiple DNS servers:**
   ```bash
   dig @8.8.8.8 pythonaisolutions.com TXT +short | grep google
   dig @1.1.1.1 pythonaisolutions.com TXT +short | grep google
   ```

---

## Option 2: HTML Tag Method (Alternative)

If you prefer to verify via an HTML tag on your website instead:

### Step 1: Access Google Search Console

1. Go to [Google Search Console](https://search.google.com/search-console)
2. Sign in with your Google account

### Step 2: Add Your Property

1. Click **Add Property**
2. Choose **URL prefix** (not Domain)
3. Enter: `https://pythonaisolutions.com`
4. Click **Continue**

### Step 3: Choose HTML Tag Method

1. Select the **HTML tag** verification method
2. You'll see something like:

```html
<meta name="google-site-verification" content="rXOxyZounnZasA3NiEM5CRii-F8cPFnrzYsaGwwPM9A" />
```

3. Copy **just the content value** (the part between the quotes after `content=`)

Example:
- Full tag: `<meta name="google-site-verification" content="rXOxyZounnZasA3NiEM5CRii-F8cPFnrzYsaGwwPM9A" />`
- Token to copy: `rXOxyZounnZasA3NiEM5CRii-F8cPFnrzYsaGwwPM9A`

### Step 4: Add Tag to Your Website

This depends on which site is serving your apex domain:

**If using GitHub Pages (www.pythonaisolutions.com → leej3.github.io):**
- Add the meta tag to the `<head>` section of your `index.html`

**If using pythonaisolutions_website (Next.js):**
- Add to `src/app/layout.tsx` in the `<head>` section

### Step 5: Deploy and Verify

1. Deploy your website changes
2. Verify the meta tag is visible:
   ```bash
   curl -s https://pythonaisolutions.com | grep google-site-verification
   ```
3. Return to Google Search Console and click **Verify**

---

## Which Method Should You Use?

| Method | Pros | Cons | Recommended For |
|--------|------|------|-----------------|
| **DNS TXT** | - Easier for this setup<br>- No code changes needed<br>- Works regardless of which site is deployed | - Requires DNS access | ✅ **Your case** (managing DNS with IaC) |
| **HTML Tag** | - Common method<br>- Direct verification | - Requires website changes<br>- Different for each site platform | Sites without DNS access |

## Current Status

Based on your configuration, your apex domain currently points to GitHub Pages IPs, and `www` points to `leej3.github.io`.

**Recommendation:** Use the **DNS TXT** method (Option 1) since you're managing DNS in this repository anyway.

## After Verification

Once verified, you can:
1. Keep the TXT record (recommended) - it doesn't hurt to leave it
2. Submit sitemaps
3. Monitor search performance
4. Request indexing for important pages

The verification stays valid as long as the DNS TXT record remains in place.
