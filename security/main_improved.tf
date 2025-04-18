# S3 bucket for website hosting
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# Enable versioning for S3 bucket
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption with KMS for S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# KMS key for S3 bucket encryption
resource "aws_kms_key" "s3_encryption_key" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

# Enable access logging for S3 bucket
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.bucket_name}-logs"

  tags = {
    Name        = "${var.bucket_name}-logs"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_ownership_controls" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "website" {
  bucket = aws_s3_bucket.website.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "logs/"
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "transition-to-ia-and-glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# S3 bucket ACL
resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "BucketOwnerEnforced" # Disables ACLs
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# S3 bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# IAM policy document for S3 bucket
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.website_distribution.arn]
    }
  }
}

# S3 event notification for object creation
resource "aws_s3_bucket_notification" "website_notification" {
  bucket = aws_s3_bucket.website.id

  topic {
    topic_arn     = aws_sns_topic.website_updates.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".html"
  }
}

# SNS topic for S3 event notifications
resource "aws_sns_topic" "website_updates" {
  name = "${var.bucket_name}-updates"
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "website_oac" {
  name                              = "${var.bucket_name}-oac"
  description                       = "OAC for ${var.bucket_name} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# WAF Web ACL for CloudFront
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  name        = "${var.bucket_name}-waf"
  description = "WAF Web ACL for CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # AWS managed rule for Log4j vulnerability protection
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS managed rule for common vulnerabilities
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.bucket_name}-waf"
    sampled_requests_enabled   = true
  }
}

# Response headers policy for CloudFront
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.bucket_name}-security-headers"
  comment = "Security headers policy"

  security_headers_config {
    content_security_policy {
      content_security_policy = "default-src 'self'; img-src 'self'; script-src 'self'; style-src 'self'; object-src 'none'; frame-ancestors 'none'"
      override                = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "same-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class
  comment             = "CloudFront distribution for ${var.bucket_name}"
  wait_for_deployment = false
  web_acl_id          = aws_wafv2_web_acl.cloudfront_waf.arn

  # Primary origin
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
  }

  # Origin failover configuration
  origin_group {
    origin_id = "OriginGroup-${var.bucket_name}"

    failover_criteria {
      status_codes = [403, 404, 500, 502]
    }

    member {
      origin_id = "S3-${var.bucket_name}"
    }

    member {
      origin_id = "S3-${var.bucket_name}-failover"
    }
  }

  # Failover origin
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${var.bucket_name}-failover"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Enable access logging
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.access_logs.bucket_regional_domain_name
    prefix          = "cloudfront/"
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3-${var.bucket_name}"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]  # Example: restrict to specific countries
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
    acm_certificate_arn            = aws_acm_certificate.cloudfront_cert.arn
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  tags = {
    Name        = "${var.bucket_name}-distribution"
    Environment = var.environment
  }
}

# ACM Certificate for CloudFront
resource "aws_acm_certificate" "cloudfront_cert" {
  provider                  = aws.us_east_1  # CloudFront requires certificates in us-east-1
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = ["www.${var.domain_name}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.bucket_name}-cert"
    Environment = var.environment
  }
}

# Sample index.html file
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Static Website with Terraform</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            color: #333;
            background-color: #f4f4f4;
        }
        .container {
            width: 80%;
            margin: 0 auto;
            padding: 2rem;
        }
        header {
            background: #35424a;
            color: white;
            padding: 1rem;
            text-align: center;
        }
        .content {
            background: white;
            padding: 2rem;
            margin-top: 1rem;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <header>
        <h1>Welcome to My Static Website</h1>
    </header>
    <div class="container">
        <div class="content">
            <h2>Hello World!</h2>
            <p>This website is hosted on AWS S3 and delivered through CloudFront.</p>
            <p>It was deployed using Terraform and GitHub Actions.</p>
        </div>
    </div>
</body>
</html>
EOF
  content_type = "text/html"
}

# Sample error.html file
resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website.id
  key          = "error.html"
  content      = <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Error - Page Not Found</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            color: #333;
            background-color: #f4f4f4;
            text-align: center;
        }
        .container {
            width: 80%;
            margin: 0 auto;
            padding: 2rem;
        }
        header {
            background: #35424a;
            color: white;
            padding: 1rem;
        }
        .content {
            background: white;
            padding: 2rem;
            margin-top: 1rem;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        .error {
            color: #e74c3c;
            font-size: 5rem;
            margin: 0;
        }
    </style>
</head>
<body>
    <header>
        <h1>Static Website</h1>
    </header>
    <div class="container">
        <div class="content">
            <p class="error">404</p>
            <h2>Page Not Found</h2>
            <p>The page you are looking for does not exist.</p>
            <a href="/">Return to Home</a>
        </div>
    </div>
</body>
</html>
EOF
  content_type = "text/html"
}