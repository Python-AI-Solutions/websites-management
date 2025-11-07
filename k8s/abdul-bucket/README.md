# GCS Bucket Admin Setup

This Terraform configuration creates a Google Cloud Storage (GCS) bucket along with a service account that has admin permissions to manage the bucket.

## Features

- Creates a GCS bucket with configurable settings
- Creates a dedicated service account with bucket admin permissions
- Generates and saves service account credentials
- Supports versioning, lifecycle rules, and encryption options
- Provides secure credential management

## Prerequisites

1. Terraform >= 1.0
2. Google Cloud SDK (`gcloud`) installed and authenticated
3. A GCP project with billing enabled
4. Appropriate permissions to create buckets and service accounts

## Usage

### 1. Initialize the configuration

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your specific values
# IMPORTANT: Choose a globally unique bucket name
```

### 2. Configure your variables

Edit `terraform.tfvars` with your project-specific values:

```hcl
project_id = "your-gcp-project-id"
bucket_name = "your-unique-bucket-name-12345"  # Must be globally unique
```

### 3. Deploy the infrastructure

```bash
# Initialize Terraform
tofu init

# Review the planned changes
tofu plan

# Apply the configuration
tofu apply
```

### 4. Access the outputs

After successful deployment:

```bash
# View all outputs
tofu output

# Get specific outputs
tofu output bucket_name
tofu output service_account_email
tofu output setup_instructions
```

## Using the Service Account Credentials

The service account key is automatically saved to `{service_account_name}-key.json` in this directory.

### Method 1: Environment Variable

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/gcs-bucket-admin-key.json"
```

### Method 2: Using with gsutil

```bash
# Activate the service account
gcloud auth activate-service-account --key-file=gcs-bucket-admin-key.json

# List bucket contents
gsutil ls gs://your-bucket-name/

# Upload a file
gsutil cp myfile.txt gs://your-bucket-name/

# Download a file
gsutil cp gs://your-bucket-name/myfile.txt .
```

### Method 3: Using with client libraries

Python example:
```python
from google.cloud import storage
import os

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = 'gcs-bucket-admin-key.json'
client = storage.Client()
bucket = client.bucket('your-bucket-name')
```

## Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | Required |
| `bucket_name` | Globally unique bucket name | Required |
| `location` | Bucket location (US, EU, asia, or specific region) | US |
| `service_account_name` | Name for the service account | gcs-bucket-admin |
| `force_destroy` | Allow destroying non-empty buckets | false |
| `uniform_bucket_level_access` | Enable uniform access (recommended) | true |
| `enable_versioning` | Enable object versioning | false |
| `enable_lifecycle_rules` | Auto-delete objects after 30 days | false |
| `grant_project_level_access` | Grant project-wide storage access | false |

## Security Best Practices

1. **Never commit service account keys to version control**
   - The `.gitignore` file is configured to exclude all `.json` files
   - Store keys securely in a secrets management system

2. **Use minimal permissions**
   - By default, the service account only has admin access to the specific bucket
   - Enable `grant_project_level_access` only if absolutely necessary

3. **Rotate keys regularly**
   - Delete and recreate the service account key periodically
   - Use `terraform apply -replace=google_service_account_key.bucket_admin_key`

4. **Enable audit logging**
   - Consider enabling Cloud Audit Logs for the bucket to track access

## Cleanup

To destroy all created resources:

```bash
# Remove all objects from the bucket first (if force_destroy is false)
gsutil rm -r gs://your-bucket-name/*

# Destroy the infrastructure
terraform destroy
```

## Troubleshooting

### "Bucket name already exists"
- Bucket names must be globally unique across all GCP projects
- Try adding a random suffix or your project ID to the bucket name

### "Permission denied"
- Ensure your user account has the necessary IAM roles:
  - `roles/storage.admin`
  - `roles/iam.serviceAccountAdmin`
  - `roles/iam.serviceAccountKeyAdmin`

### "API not enabled"
- Enable required APIs:
  ```bash
  gcloud services enable storage.googleapis.com
  gcloud services enable iam.googleapis.com
  ```

## Additional Resources

- [GCS Documentation](https://cloud.google.com/storage/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCS Best Practices](https://cloud.google.com/storage/docs/best-practices)
