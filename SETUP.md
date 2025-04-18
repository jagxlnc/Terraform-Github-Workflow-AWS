# Setup Guide for GitHub Actions with Terraform and AWS

This guide explains how to set up the required secrets and configurations for deploying the static website using GitHub Actions.

## Required GitHub Secrets

Add the following secrets to your GitHub repository:

1. **AWS Credentials**:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
   - `AWS_REGION`: The AWS region to deploy to (e.g., `us-east-1`)

2. **Terraform Variables**:
   - `TF_VAR_BUCKET_NAME`: The name for your S3 bucket (must be globally unique)

3. **Optional - Terraform Cloud**:
   - `TF_API_TOKEN`: Your Terraform Cloud API token (if using Terraform Cloud)

## Setting Up GitHub Secrets

1. Go to your GitHub repository
2. Click on "Settings" > "Secrets and variables" > "Actions"
3. Click "New repository secret"
4. Add each of the secrets listed above

## AWS IAM Setup

Create an IAM user with the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*",
                "cloudfront:*",
                "iam:GetPolicy",
                "iam:GetPolicyVersion",
                "iam:ListAttachedRolePolicies",
                "iam:ListPolicies",
                "iam:ListPolicyVersions",
                "iam:ListRoles"
            ],
            "Resource": "*"
        }
    ]
}
```

**Note**: For production environments, it's recommended to use more restrictive permissions.

## Setting Up Terraform Backend (Optional)

For team environments, it's recommended to use a remote backend for Terraform state. To set up an S3 backend:

1. Create an S3 bucket for Terraform state:

```bash
aws s3api create-bucket --bucket your-terraform-state-bucket --region us-east-1
```

2. Enable versioning on the bucket:

```bash
aws s3api put-bucket-versioning --bucket your-terraform-state-bucket --versioning-configuration Status=Enabled
```

3. Create a DynamoDB table for state locking:

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

4. Uncomment and update the backend configuration in `backend.tf`

## Workflow Usage

### Automated Deployments

- **Pull Requests**: When you create a PR to the main branch, the workflow will run validation and planning steps
- **Merges to Main**: When code is merged to the main branch, it will automatically deploy to the dev environment
- **Manual Deployments**: You can manually trigger a deployment to any environment using the workflow dispatch event

### Manual Deployment

1. Go to the "Actions" tab in your repository
2. Select the "Terraform CI/CD Pipeline" workflow
3. Click "Run workflow"
4. Select the branch and environment, then click "Run workflow"

### Destroying Resources

To destroy the infrastructure:

1. Go to the "Actions" tab in your repository
2. Select the "Terraform Destroy" workflow
3. Click "Run workflow"
4. Select the environment and type "destroy" to confirm
5. Click "Run workflow"
