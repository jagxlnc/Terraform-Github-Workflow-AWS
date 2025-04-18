# Static Website with S3 and CloudFront

This module creates an AWS S3 bucket configured for static website hosting and a CloudFront distribution to serve the content securely and with improved performance.

## Features

- S3 bucket configured for website hosting
- CloudFront distribution with Origin Access Control
- Secure bucket policy that only allows access from CloudFront
- Sample HTML files (index.html and error.html)
- IPv6 support

## Usage

```hcl
module "static_website" {
  source = "./"
  
  bucket_name = "my-static-website-bucket"
  environment = "dev"
}
```

## Prerequisites

- AWS account with appropriate permissions
- Terraform installed (version >= 1.2.0)
- AWS CLI configured

## Deployment Instructions

1. Clone this repository
2. Navigate to the directory containing the Terraform files
3. Create a `terraform.tfvars` file based on the example file
4. Initialize Terraform:
   ```
   terraform init
   ```
5. Plan the deployment:
   ```
   terraform plan
   ```
6. Apply the configuration:
   ```
   terraform apply
   ```
7. After successful deployment, the CloudFront domain name will be displayed in the outputs

## Uploading Content

You can upload additional content to the S3 bucket using the AWS CLI:

```bash
aws s3 sync ./your-website-files/ s3://your-bucket-name/
```

Or add more `aws_s3_object` resources in the Terraform configuration.

## Cleanup

To destroy all resources created by this Terraform configuration:

```
terraform destroy
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|--------|
| region | AWS region to deploy resources | string | "us-east-1" |
| bucket_name | Name of the S3 bucket | string | - |
| environment | Environment name | string | "dev" |
| cloudfront_price_class | CloudFront price class | string | "PriceClass_100" |

## Outputs

| Name | Description |
|------|-------------|
| s3_bucket_name | Name of the S3 bucket |
| s3_bucket_arn | ARN of the S3 bucket |
| s3_website_endpoint | S3 website endpoint |
| cloudfront_distribution_id | ID of the CloudFront distribution |
| cloudfront_domain_name | Domain name of the CloudFront distribution |
