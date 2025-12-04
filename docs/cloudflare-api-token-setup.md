# Cloudflare API Token Setup

## Required Permissions

Your Cloudflare API token needs these permissions to manage DNS with this repository:

### Minimum Required Permissions

```
Permissions:
  Account | Zone | Create          ← Required to create new zones
  Zone    | Zone | Edit            ← Required to manage zone settings
  Zone    | DNS  | Edit            ← Required to manage DNS records

Account Resources:
  Include | <Your Account Name>

Zone Resources:
  Include | All zones from account
  (or specific zone: example-organization.com)
```

## Creating a New API Token

1. **Go to Cloudflare Dashboard**
   - Navigate to: https://dash.cloudflare.com/profile/api-tokens

2. **Create Token**
   - Click **Create Token**
   - Choose **Create Custom Token**

3. **Set Permissions**
   - Add three permission rows:
     - **Account** | Zone | Create
     - **Zone** | Zone | Edit
     - **Zone** | DNS | Edit

4. **Set Account Resources**
   - Under "Account Resources":
     - Select: **Include** → **<Your Account>**

5. **Set Zone Resources**
   - Under "Zone Resources":
     - Option A (Recommended): **Include** → **All zones from account**
     - Option B: **Include** → **Specific zone** → `example-organization.com`

6. **Optional: Set IP/TTL Restrictions**
   - **Client IP Address Filtering**: Leave blank (or add your IPs for extra security)
   - **TTL**: Leave as default or set expiration date

7. **Create and Save**
   - Click **Continue to summary**
   - Review permissions
   - Click **Create Token**
   - **Copy the token immediately** (you won't see it again!)

## Updating .env File

Save the token to your `.env` file:

```bash
# Edit .env file
CLOUDFLARE_API_TOKEN=your_token_here_abc123xyz...
CLOUDFLARE_ACCOUNT_ID=your_account_id_here
```

## Getting Your Account ID

If you don't have your account ID:

```bash
# Run the helper script
bash scripts/get-account-id.sh
```

Or get it from the Cloudflare dashboard:
1. Go to: https://dash.cloudflare.com
2. Click on any zone
3. Scroll down in the right sidebar
4. Copy the "Account ID"

## Verifying Token Works

After updating your token:

```bash
# Test with a plan (doesn't make changes)
pixi run plan-prod
```

You should see a plan output without authentication errors.

## Common Permission Errors

### Error: "Requires permission to create zones"
```
Error: error creating zone: Requires permission "com.cloudflare.api.account.zone.create"
```

**Fix**: Add **Account | Zone | Create** permission to your token

### Error: "Authentication error"
```
Error: error reading zone: Authentication error (10000)
```

**Fix**: Check that:
- Token is correctly copied to `.env`
- No extra spaces in the token
- Token hasn't expired

### Error: "Insufficient permissions to edit zone"
```
Error: error updating zone: Insufficient permissions
```

**Fix**: Add **Zone | Zone | Edit** permission

### Error: "Insufficient permissions to edit DNS"
```
Error: error creating DNS record: Insufficient permissions
```

**Fix**: Add **Zone | DNS | Edit** permission

## Token Security Best Practices

1. **Never commit tokens to git**
   - `.env` is in `.gitignore` - keep it that way
   - Never paste tokens in issues, docs, or code

2. **Use specific scope when possible**
   - Limit to specific zones if you only manage one domain
   - Set IP restrictions if you have a static IP

3. **Set expiration dates**
   - Good for CI/CD tokens
   - Forces periodic rotation

4. **Rotate tokens periodically**
   - Create new token
   - Update `.env`
   - Test with `pixi run plan-prod`
   - Delete old token in Cloudflare dashboard

5. **Use different tokens for different environments**
   - Separate token for CI/CD
   - Separate token for local development
   - Makes revocation easier if compromised

## Troubleshooting

### "The token appears to be invalid"

Check:
```bash
# Verify token is set
grep CLOUDFLARE_API_TOKEN .env

# Should show: CLOUDFLARE_API_TOKEN=your_token...
# Not: CLOUDFLARE_API_TOKEN=
```

### "Token works locally but not in CI"

- Check that GitHub Secrets are set correctly
- Verify no extra spaces when copying token
- Ensure token hasn't expired

### Need to regenerate token?

If you lost your token or it's compromised:
1. Delete the old token in Cloudflare dashboard
2. Create a new one following steps above
3. Update `.env` with new token
4. Test with `pixi run plan-prod`
