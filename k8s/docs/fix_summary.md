# Service Account Fix Summary

## ❌ Previous State (Causing 403 Errors)

**Problem**: Cross-project permission mismatch
- **Service Account Created In**: `divine-surface-468015-h9`
- **IAM Roles Applied To**: `midyear-pattern-470017-b8`
- **APIs Enabled In**: `midyear-pattern-470017-b8`
- **Error**: `Permission denied to list services for consumer container [projects/622290015447]`

**Root Cause**: Service account existed in one project but permissions were applied to a different project.

## ✅ Current State (Fixed)

**Solution**: Everything standardized in one project
- **Service Account**: `k8s-admin@midyear-pattern-470017-b8.iam.gserviceaccount.com`
- **Project**: `midyear-pattern-470017-b8` (consistent everywhere)
- **All Resources**: Created and configured in the same project

### IAM Roles Assigned:
- `roles/container.admin` - Manage GKE clusters
- `roles/compute.viewer` - View networks/zones
- `roles/serviceusage.serviceUsageAdmin` - Enable/disable APIs
- `roles/viewer` - Basic read access (enables resourcemanager.projects.get)
- `roles/serviceusage.serviceUsageViewer` - **Minimum needed to list enabled services**

### APIs Enabled:
- `compute.googleapis.com` - Compute Engine API
- `container.googleapis.com` - Google Kubernetes Engine API
- `serviceusage.googleapis.com` - **Service Usage API (required for IaC tools)**
- `cloudresourcemanager.googleapis.com` - **Cloud Resource Manager API (required for IaC tools)**

## 🎯 Why the Error is Now Fixed

1. **Project Consistency**: Service account, permissions, and APIs are all in `midyear-pattern-470017-b8`
2. **Service Usage Permissions**: Added `roles/serviceusage.serviceUsageViewer` which provides the exact permission needed to list services
3. **API Enablement**: `serviceusage.googleapis.com` is now enabled in the correct project
4. **Resource Manager Access**: `roles/viewer` provides `resourcemanager.projects.get` permission

## 🧪 How to Verify (when gcloud is available)

```bash
# Authenticate with the service account
gcloud auth activate-service-account --key-file=k8s-admin-key.json

# Set the correct project
gcloud config set project midyear-pattern-470017-b8

# Test the previously failing operation
gcloud services list --enabled

# This should now work without 403 errors!
```

## 📝 Key Learnings

The original error occurred because:
1. Terraform created the service account in a different project than configured
2. Cross-project IAM bindings were attempted but insufficient
3. Missing `serviceusage.serviceUsageViewer` role specifically for listing services
4. Required APIs not enabled in the service account's project

All these issues have been resolved by ensuring complete project consistency and proper permissions.
