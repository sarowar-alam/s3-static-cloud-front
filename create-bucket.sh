#!/bin/bash

#############################################
# Create Private S3 Bucket for CloudFront
# Region: ap-south-1
# Bucket: ostad-devops-batch-10
# Domain: bmiostad.ostaddevops.click
#############################################

set -e  # Exit on any error

# ============================
# Variables
# ============================
BUCKET="ostad-devops-batch-10"
REGION="ap-south-1"
PROFILE="sarowar-ostad"
DOMAIN="bmiostad.ostaddevops.click"

echo "================================================"
echo "Creating Private S3 Bucket for CloudFront"
echo "================================================"
echo ""
echo "AWS Profile: $PROFILE"
echo "Bucket Name: $BUCKET"
echo "Region: $REGION"
echo "Domain: $DOMAIN"
echo ""

# ============================
# 1. Create the bucket
# ============================
echo "Step 1: Creating S3 bucket..."
aws s3 mb s3://"$BUCKET" \
  --region "$REGION" \
  --profile "$PROFILE"

if [ $? -eq 0 ]; then
    echo "✅ Bucket created successfully"
else
    echo "⚠️  Bucket may already exist or creation failed"
fi

# ============================
# 2. Keep Block Public Access ENABLED (default)
# ============================
echo ""
echo "Step 2: Ensuring Block Public Access is enabled..."
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --profile "$PROFILE" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "✅ Bucket is private (accessible only via CloudFront)"

# ============================
# 3. Upload files with correct MIME type
# ============================
echo ""
echo "Step 3: Uploading HTML files..."

if [ -f "index.html" ]; then
    aws s3 cp index.html s3://"$BUCKET"/index.html \
      --content-type "text/html; charset=utf-8" \
      --profile "$PROFILE"
    echo "✅ Uploaded: index.html"
else
    echo "⚠️  Warning: index.html not found"
fi

if [ -f "error.html" ]; then
    aws s3 cp error.html s3://"$BUCKET"/error.html \
      --content-type "text/html; charset=utf-8" \
      --profile "$PROFILE"
    echo "✅ Uploaded: error.html"
else
    echo "⚠️  Warning: error.html not found"
fi

# ============================
# 4. Enable static website hosting
# ============================
echo ""
echo "Step 4: Enabling static website hosting..."
aws s3 website s3://"$BUCKET"/ \
  --index-document index.html \
  --error-document error.html \
  --profile "$PROFILE"

echo "✅ Static website hosting enabled"

# ============================
# 5. Output summary
# ============================
echo ""
echo "================================================"
echo "✅ S3 Bucket Setup Complete!"
echo "================================================"
echo ""
echo "Bucket Name: $BUCKET"
echo "Region: $REGION"
echo "S3 Origin: $BUCKET.s3.$REGION.amazonaws.com"
echo ""
echo "⚠️  IMPORTANT:"
echo "- Bucket is PRIVATE (not publicly accessible)"
echo "- Access will be granted to CloudFront via OAC"
echo "- Bucket policy will be updated in step 07-update-bucket-policy.sh"
echo ""
echo "Next step: Run bash 06-create-cloudfront-oac.sh"
echo ""
