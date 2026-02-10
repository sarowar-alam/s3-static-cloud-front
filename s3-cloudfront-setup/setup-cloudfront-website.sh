#!/bin/bash

#############################################
# S3 + CloudFront Static Website Setup
# Creates a PRIVATE S3 bucket with CloudFront
# distribution for secure HTTPS delivery
#############################################

set -e # Exit on any error (disabled for optional operations)

# ============================
# Configuration Variables
# ============================
BUCKET_NAME="ostad-devops-batch-2026-cf"  # Change this to your desired bucket name
AWS_REGION="ap-south-1"  # Change this to your preferred region
AWS_PROFILE="sarowar-ostad"  # Change this to your AWS CLI profile name
OAC_NAME="${BUCKET_NAME}-oac"  # Origin Access Control name

echo ""
echo "  S3 + CloudFront Static Website Setup Script "
echo ""
echo ""
echo "Configuration:"
echo "  Bucket Name: $BUCKET_NAME"
echo "  AWS Region: $AWS_REGION"
echo "  AWS Profile: $AWS_PROFILE"
echo "  OAC Name: $OAC_NAME"
echo ""
echo "This setup will:"
echo "  - Create a PRIVATE S3 bucket (public access blocked)"
echo "  - Upload your website files"
echo "  - Create CloudFront distribution with HTTPS"
echo "  - Configure Origin Access Control for security"
echo ""
read -p "Continue with this configuration? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
 echo "Setup cancelled."
 exit 1
fi

echo ""
echo ""
echo "Step 1: Creating Private S3 Bucket"
echo ""

aws s3 mb s3://"$BUCKET_NAME" \
 --region "$AWS_REGION" \
 --profile "$AWS_PROFILE" 2>&1 > /dev/null

if [ $? -eq 0 ]; then
 echo " Bucket '$BUCKET_NAME' created successfully"
else
 echo "  Bucket may already exist or creation failed"
 echo "Continuing with existing bucket..."
fi

echo ""
echo ""
echo "Step 2: Verifying Public Access is Blocked (Security)"
echo ""

aws s3api put-public-access-block \
 --bucket "$BUCKET_NAME" \
 --profile "$AWS_PROFILE" \
 --public-access-block-configuration \
 BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

if [ $? -eq 0 ]; then
 echo " Public access blocked (bucket is private)"
else
 echo " Failed to configure block public access"
 exit 1
fi

echo ""
echo ""
echo "Step 3: Uploading Website Files"
echo ""

# Upload index.html
if [ -f "../index.html" ]; then
 aws s3 cp ../index.html s3://"$BUCKET_NAME"/index.html \
 --content-type "text/html; charset=utf-8" \
 --profile "$AWS_PROFILE"
 
 if [ $? -eq 0 ]; then
 echo " Uploaded: index.html"
 else
 echo " Failed to upload index.html"
 exit 1
 fi
else
 echo " ERROR: index.html not found in parent directory"
 exit 1
fi

# Upload error.html
if [ -f "../error.html" ]; then
 aws s3 cp ../error.html s3://"$BUCKET_NAME"/error.html \
 --content-type "text/html; charset=utf-8" \
 --profile "$AWS_PROFILE"
 
 if [ $? -eq 0 ]; then
 echo " Uploaded: error.html"
 else
 echo "  Failed to upload error.html"
 fi
else
 echo "  Warning: error.html not found (optional)"
fi

echo ""
echo ""
echo "Step 4: Creating Origin Access Control (OAC)"
echo ""

# Check if OAC already exists
OAC_LIST=$(aws cloudfront list-origin-access-controls --profile "$AWS_PROFILE" 2>&1)
OAC_ID=""

if [ $? -eq 0 ]; then
 OAC_ID=$(echo "$OAC_LIST" | jq -r ".OriginAccessControlList.Items[] | select(.Name==\"$OAC_NAME\") | .Id" 2>/dev/null)
fi

if [ -n "$OAC_ID" ]; then
 echo " Using existing Origin Access Control"
 echo "  OAC ID: $OAC_ID"
else
 # Create OAC configuration
 cat > /tmp/oac-config.json <<EOF
{
 "Name": "$OAC_NAME",
 "Description": "OAC for $BUCKET_NAME",
 "SigningProtocol": "sigv4",
 "SigningBehavior": "always",
 "OriginAccessControlOriginType": "s3"
}
EOF

 # Create OAC
 OAC_OUTPUT=$(aws cloudfront create-origin-access-control \
 --origin-access-control-config file:///tmp/oac-config.json \
 --profile "$AWS_PROFILE" 2>&1)
 
 rm -f /tmp/oac-config.json
 
 if [ $? -eq 0 ]; then
 OAC_ID=$(echo "$OAC_OUTPUT" | jq -r '.OriginAccessControl.Id')
 echo " Origin Access Control created"
 echo "  OAC ID: $OAC_ID"
 else
 echo " Failed to create Origin Access Control"
 echo "$OAC_OUTPUT"
 exit 1
 fi
fi

echo ""
echo ""
echo "Step 5: Creating CloudFront Distribution"
echo ""

# Check if distribution already exists for this bucket
DIST_LIST=$(aws cloudfront list-distributions --profile "$AWS_PROFILE" 2>&1)
DISTRIBUTION_ID=""
DOMAIN_NAME=""

if [ $? -eq 0 ]; then
 DISTRIBUTION_ID=$(echo "$DIST_LIST" | jq -r ".DistributionList.Items[] | select(.Origins.Items[0].DomainName | contains(\"$BUCKET_NAME\")) | .Id" 2>/dev/null | head -n 1)
 if [ -n "$DISTRIBUTION_ID" ]; then
 DOMAIN_NAME=$(echo "$DIST_LIST" | jq -r ".DistributionList.Items[] | select(.Id==\"$DISTRIBUTION_ID\") | .DomainName" 2>/dev/null)
 fi
fi

if [ -n "$DISTRIBUTION_ID" ]; then
 echo " Using existing CloudFront distribution"
 echo "  Distribution ID: $DISTRIBUTION_ID"
 echo "  Domain Name: $DOMAIN_NAME"
else
 # Create CloudFront distribution configuration
 CALLER_REFERENCE=$(date +%s)
 ORIGIN_DOMAIN="${BUCKET_NAME}.s3.${AWS_REGION}.amazonaws.com"
 
 cat > /tmp/cf-distribution.json <<EOF
{
 "CallerReference": "$CALLER_REFERENCE",
 "Comment": "CloudFront distribution for $BUCKET_NAME",
 "Enabled": true,
 "DefaultRootObject": "index.html",
 "Origins": {
 "Quantity": 1,
 "Items": [
 {
 "Id": "S3-$BUCKET_NAME",
 "DomainName": "$ORIGIN_DOMAIN",
 "S3OriginConfig": {
 "OriginAccessIdentity": ""
 },
 "OriginAccessControlId": "$OAC_ID"
 }
 ]
 },
 "DefaultCacheBehavior": {
 "TargetOriginId": "S3-$BUCKET_NAME",
 "ViewerProtocolPolicy": "redirect-to-https",
 "AllowedMethods": {
 "Quantity": 2,
 "Items": ["GET", "HEAD"],
 "CachedMethods": {
 "Quantity": 2,
 "Items": ["GET", "HEAD"]
 }
 },
 "ForwardedValues": {
 "QueryString": false,
 "Cookies": {
 "Forward": "none"
 }
 },
 "MinTTL": 0,
 "DefaultTTL": 86400,
 "MaxTTL": 31536000,
 "Compress": true,
 "TrustedSigners": {
 "Enabled": false,
 "Quantity": 0
 }
 },
 "CustomErrorResponses": {
 "Quantity": 1,
 "Items": [
 {
 "ErrorCode": 404,
 "ResponsePagePath": "/error.html",
 "ResponseCode": "404",
 "ErrorCachingMinTTL": 300
 }
 ]
 }
}
EOF

 echo "Creating CloudFront distribution (this may take a few minutes)..."
 
 CF_OUTPUT=$(aws cloudfront create-distribution \
 --distribution-config file:///tmp/cf-distribution.json \
 --profile "$AWS_PROFILE" 2>&1)
 
 rm -f /tmp/cf-distribution.json
 
 if [ $? -eq 0 ]; then
 DISTRIBUTION_ID=$(echo "$CF_OUTPUT" | jq -r '.Distribution.Id')
 DOMAIN_NAME=$(echo "$CF_OUTPUT" | jq -r '.Distribution.DomainName')
 echo " CloudFront distribution created"
 echo "  Distribution ID: $DISTRIBUTION_ID"
 echo "  Domain Name: $DOMAIN_NAME"
 else
 echo " Failed to create CloudFront distribution"
 echo "$CF_OUTPUT"
 exit 1
 fi
fi

echo ""
echo ""
echo "Step 6: Updating S3 Bucket Policy for CloudFront Access"
echo ""

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text 2>&1)

if [ $? -ne 0 ]; then
 echo " Failed to get AWS account ID"
 exit 1
fi

# Create bucket policy for CloudFront OAC
cat > /tmp/cf-bucket-policy.json <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
 {
 "Sid": "AllowCloudFrontServicePrincipal",
 "Effect": "Allow",
 "Principal": {
 "Service": "cloudfront.amazonaws.com"
 },
 "Action": "s3:GetObject",
 "Resource": "arn:aws:s3:::$BUCKET_NAME/*",
 "Condition": {
 "StringEquals": {
 "AWS:SourceArn": "arn:aws:cloudfront::$ACCOUNT_ID:distribution/$DISTRIBUTION_ID"
 }
 }
 }
 ]
}
EOF

aws s3api put-bucket-policy \
 --bucket "$BUCKET_NAME" \
 --policy file:///tmp/cf-bucket-policy.json \
 --profile "$AWS_PROFILE" 2>&1 > /dev/null

rm -f /tmp/cf-bucket-policy.json

if [ $? -eq 0 ]; then
 echo " Bucket policy applied for CloudFront access"
else
 echo " Failed to apply bucket policy"
 exit 1
fi

echo ""
echo ""
echo "  Setup Complete! "
echo ""
echo ""
echo "Your static website is now accessible via CloudFront:"
echo ""
echo "  HTTPS URL: https://$DOMAIN_NAME"
echo ""
echo ""
echo "Configuration Details:"
echo "  - S3 Bucket: $BUCKET_NAME (private)"
echo "  - AWS Region: $AWS_REGION"
echo "  - CloudFront Dist ID: $DISTRIBUTION_ID"
echo "  - CloudFront Domain: $DOMAIN_NAME"
echo "  - Origin Access: OAC (Origin Access Control)"
echo "  - Protocol: HTTPS (with redirect from HTTP)"
echo "  - Index Document: index.html"
echo "  - Error Document: error.html"
echo ""
echo ""
echo " IMPORTANT NOTES:"
echo "  - CloudFront distribution is deploying (takes 5-15 minutes)"
echo "  - S3 bucket is PRIVATE - only accessible via CloudFront"
echo "  - All traffic is served over HTTPS"
echo "  - Content is cached globally for better performance"
echo ""
echo " To update your website:"
echo "  1. Upload new files to S3:"
echo "  aws s3 cp yourfile.html s3://$BUCKET_NAME/ --content-type \"text/html; charset=utf-8\" --profile $AWS_PROFILE"
echo ""
echo "  2. Invalidate CloudFront cache:"
echo "  aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths \"/*\" --profile $AWS_PROFILE"
echo ""
echo " To check distribution status:"
echo "  aws cloudfront get-distribution --id $DISTRIBUTION_ID --profile $AWS_PROFILE --query 'Distribution.Status'"
echo ""
echo "  To delete everything (cleanup):"
echo ""
echo "  1. Disable CloudFront distribution:"
echo "  CONFIG=\$(aws cloudfront get-distribution-config --id $DISTRIBUTION_ID --profile $AWS_PROFILE)"
echo "  ETAG=\$(echo \$CONFIG | jq -r '.ETag')"
echo "  echo \$CONFIG | jq '.DistributionConfig | .Enabled = false' > dist.json"
echo "  aws cloudfront update-distribution --id $DISTRIBUTION_ID --if-match \$ETAG --distribution-config file://dist.json --profile $AWS_PROFILE"
echo ""
echo "  2. Wait for deployment (5-10 mins) and delete CloudFront:"
echo "  # Check status until 'Deployed'"
echo "  aws cloudfront get-distribution --id $DISTRIBUTION_ID --query 'Distribution.Status' --profile $AWS_PROFILE"
echo ""
echo "  # When status is 'Deployed', delete it"
echo "  ETAG=\$(aws cloudfront get-distribution --id $DISTRIBUTION_ID --profile $AWS_PROFILE | jq -r '.ETag')"
echo "  aws cloudfront delete-distribution --id $DISTRIBUTION_ID --if-match \$ETAG --profile $AWS_PROFILE"
echo ""
echo "  3. Empty and delete S3 bucket:"
echo "  aws s3 rm s3://$BUCKET_NAME --recursive --profile $AWS_PROFILE"
echo "  aws s3 rb s3://$BUCKET_NAME --profile $AWS_PROFILE"
echo ""
echo "  4. Delete Origin Access Control:"
echo "  OAC_ETAG=\$(aws cloudfront get-origin-access-control --id $OAC_ID --profile $AWS_PROFILE | jq -r '.ETag')"
echo "  aws cloudfront delete-origin-access-control --id $OAC_ID --if-match \$OAC_ETAG --profile $AWS_PROFILE"
echo ""
