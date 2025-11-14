# Remote State Backend Setup

This directory contains a one-time setup to create the remote state storage.

## Purpose

Creates a GCS bucket (or S3 bucket) to store Terraform state remotely for collaboration.

## Usage

### Option A: GCS (Google Cloud Storage)

```bash
cd remote-state-setup
tofu init
tofu apply -var 'project_id=midyear-pattern-470017-b8'

# Note the bucket name from output
# Then update ../main.tf backend configuration
```

### Option B: S3 (AWS)

```bash
cd remote-state-setup
tofu init
tofu apply -var 'bucket_name=k8s-tfstate-UNIQUE_NAME'

# Note the bucket name from output
# Then update ../main.tf backend configuration
```

## After Creation

1. Update `../main.tf` backend block
2. Run `tofu init` in parent directory
