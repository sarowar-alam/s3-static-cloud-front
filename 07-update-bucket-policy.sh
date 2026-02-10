#!/bin/bash

#############################################
# Update S3 Bucket Policy for CloudFront OAC Access
# Grants CloudFront distribution access to private S3 bucket
# Bucket: ostad-devops-batch-10
#############################################

set -e  # Exit on any error

# Configuration
BUCKET="ostad-devops-batch-10"
BUCKET_REGION="ap-south-1"
PROFILE="sarowar-ostad"

echo "================================================"
echo "Updating S3 Bucket Policy for CloudFront OAC"
echo "================================================"
echo ""

# Check required files
if [ ! -f "distribution-id.txt" ]; then
    echo "❌ ERROR: distribution-id.txt not found"
    echo "Please run 06-create-cloudfront.sh first"
    exit 1
fi

# Load distribution ID
DISTRIBUTION_ID=$(cat distribution-id.txt)

echo "Bucket: $BUCKET"
echo "Region: $BUCKET_REGION"
echo "CloudFront Distribution ID: $DISTRIBUTION_ID"
echo ""

# Get AWS Account ID
echo "Getting AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
echo "✅ Account ID: $ACCOUNT_ID"
echo ""

# Create bucket policy
echo "Creating bucket policy..."

cat > bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudFrontOAC",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudfront::$ACCOUNT_ID:distribution/$DISTRIBUTION_ID"
                }
            }
        }
    ]
}
EOF

echo "✅ Bucket policy created: bucket-policy.json"
echo ""

# Apply bucket policy
echo "Applying bucket policy to S3 bucket..."

aws s3api put-bucket-policy \
    --bucket "$BUCKET" \
    --policy file://bucket-policy.json \
    --profile "$PROFILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "✅ Bucket Policy Updated Successfully!"
    echo "================================================"
    echo ""
    echo "The S3 bucket is now accessible via CloudFront OAC"
    echo ""
    echo "Policy details:"
    echo "- Principal: cloudfront.amazonaws.com"
    echo "- Action: s3:GetObject"
    echo "- Resource: arn:aws:s3:::$BUCKET/*"
    echo "- Condition: Distribution $DISTRIBUTION_ID only"
    echo ""
    echo "✅ Bucket remains private to the public"
    echo "✅ Only CloudFront can access bucket objects"
    echo ""
    echo "Next step: Run bash 08-create-route53-record.sh"
else
    echo ""
    echo "❌ Failed to update bucket policy"
    exit 1
fi
