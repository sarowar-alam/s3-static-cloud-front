#!/bin/bash

#############################################
# S3 Static Website Setup
# Creates a PUBLIC S3 bucket and enables 
# static website hosting for direct browsing
#############################################

set -e # Exit on any error

# ============================
# Configuration Variables
# ============================
BUCKET_NAME="ostad-devops-batch-2026"  # Change this to your desired bucket name
AWS_REGION="ap-south-1"  # Change this to your preferred region
AWS_PROFILE="sarowar-ostad"  # Change this to your AWS CLI profile name

echo ""
echo "  S3 Static Website Setup Script "
echo ""
echo ""
echo "Configuration:"
echo "  Bucket Name: $BUCKET_NAME"
echo "  AWS Region: $AWS_REGION"
echo "  AWS Profile: $AWS_PROFILE"
echo ""
read -p "Continue with this configuration? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
 echo "Setup cancelled."
 exit 1
fi

echo ""
echo ""
echo "Step 1: Creating S3 Bucket"
echo ""

aws s3 mb s3://"$BUCKET_NAME" \
 --region "$AWS_REGION" \
 --profile "$AWS_PROFILE"

if [ $? -eq 0 ]; then
 echo " Bucket '$BUCKET_NAME' created successfully"
else
 echo "  Bucket may already exist or creation failed"
 echo "Continuing with existing bucket..."
fi

echo ""
echo ""
echo "Step 2: Disabling Block Public Access"
echo ""

aws s3api put-public-access-block \
 --bucket "$BUCKET_NAME" \
 --profile "$AWS_PROFILE" \
 --public-access-block-configuration \
 BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

echo " Block Public Access disabled"

echo ""
echo ""
echo "Step 3: Uploading Website Files"
echo ""

# Upload index.html
if [ -f "../index.html" ]; then
 aws s3 cp ../index.html s3://"$BUCKET_NAME"/index.html \
 --content-type "text/html; charset=utf-8" \
 --profile "$AWS_PROFILE"
 echo " Uploaded: index.html"
else
 echo " ERROR: index.html not found in parent directory"
 exit 1
fi

# Upload error.html
if [ -f "../error.html" ]; then
 aws s3 cp ../error.html s3://"$BUCKET_NAME"/error.html \
 --content-type "text/html; charset=utf-8" \
 --profile "$AWS_PROFILE"
 echo " Uploaded: error.html"
else
 echo "  Warning: error.html not found (optional)"
fi

echo ""
echo ""
echo "Step 4: Enabling Static Website Hosting"
echo ""

aws s3 website s3://"$BUCKET_NAME"/ \
 --index-document index.html \
 --error-document error.html \
 --profile "$AWS_PROFILE"

echo " Static website hosting enabled"

echo ""
echo ""
echo "Step 5: Creating Bucket Policy for Public Read Access"
echo ""

# Check if bucket-policy.json exists
if [ ! -f "bucket-policy.json" ]; then
 echo " ERROR: bucket-policy.json not found in current directory"
 exit 1
fi

# Read the policy template and replace placeholder with actual bucket name
sed "s/BUCKET_NAME_PLACEHOLDER/$BUCKET_NAME/g" bucket-policy.json > /tmp/bucket-policy-temp.json

# Apply bucket policy
aws s3api put-bucket-policy \
 --bucket "$BUCKET_NAME" \
 --policy file:///tmp/bucket-policy-temp.json \
 --profile "$AWS_PROFILE"

echo " Public read bucket policy applied"

# Clean up temporary file
rm -f /tmp/bucket-policy-temp.json

echo ""
echo ""
echo "  Setup Complete! "
echo ""
echo ""
echo "Your static website is now live and accessible at:"
echo ""
echo "  http://$BUCKET_NAME.s3-website.$AWS_REGION.amazonaws.com"
echo ""
echo ""
echo "Website Details:"
echo "  Bucket Name: $BUCKET_NAME"
echo "  AWS Region: $AWS_REGION"
echo "  Index Document: index.html"
echo "  Error Document: error.html"
echo "  Access: Public (HTTP only)"
echo ""
echo ""
echo " Notes:"
echo "  Website is accessible via HTTP (not HTTPS)"
echo "  For HTTPS and custom domain, use CloudFront"
echo "  Bucket is publicly readable by anyone"
echo ""
echo " To update your website:"
echo "  aws s3 cp yourfile.html s3://$BUCKET_NAME/ \\"
echo "  --content-type \"text/html; charset=utf-8\" \\"
echo "  --profile $AWS_PROFILE"
echo ""
echo "  To delete the bucket and website:"
echo "  aws s3 rb s3://$BUCKET_NAME --force --profile $AWS_PROFILE"
echo ""
