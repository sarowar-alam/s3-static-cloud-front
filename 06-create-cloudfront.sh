#!/bin/bash

#############################################
# Create CloudFront Distribution
# With SSL Certificate and Custom Domain
# Domain: bmiostad.ostaddevops.click
# S3 Origin: ostad-devops-batch-10 (ap-south-1)
#############################################

set -e  # Exit on any error

# Configuration
BUCKET="ostad-devops-batch-10"
BUCKET_REGION="ap-south-1"
DOMAIN="bmiostad.ostaddevops.click"
PROFILE="sarowar-ostad"
CALLER_REFERENCE="ostad-devops-$(date +%s)"

echo "================================================"
echo "Creating CloudFront Distribution"
echo "================================================"
echo ""

# Check required files
if [ ! -f "certificate-arn.txt" ]; then
    echo "❌ ERROR: certificate-arn.txt not found"
    echo "Please run 04-import-to-acm.sh first"
    exit 1
fi

if [ ! -f "oac-id.txt" ]; then
    echo "❌ ERROR: oac-id.txt not found"
    echo "Please run 06-create-cloudfront-oac.sh first"
    exit 1
fi

# Load certificate ARN and OAC ID
CERT_ARN=$(cat certificate-arn.txt)
OAC_ID=$(cat oac-id.txt)

echo "Domain: $DOMAIN"
echo "S3 Bucket: $BUCKET ($BUCKET_REGION)"
echo "Certificate ARN: $CERT_ARN"
echo "OAC ID: $OAC_ID"
echo ""

# Verify AWS credentials
echo "Verifying AWS credentials..."
aws sts get-caller-identity --profile "$PROFILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
    echo "✅ AWS credentials verified (Account: $ACCOUNT_ID)"
else
    echo "❌ ERROR: AWS credentials not configured"
    exit 1
fi

# Create CloudFront distribution configuration
echo ""
echo "Creating CloudFront distribution configuration..."

cat > cloudfront-config.json <<EOF
{
    "CallerReference": "$CALLER_REFERENCE",
    "Comment": "CloudFront distribution for $DOMAIN",
    "Enabled": true,
    "DefaultRootObject": "index.html",
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "S3-$BUCKET",
                "DomainName": "$BUCKET.s3.$BUCKET_REGION.amazonaws.com",
                "OriginAccessControlId": "$OAC_ID",
                "S3OriginConfig": {
                    "OriginAccessIdentity": ""
                },
                "CustomHeaders": {
                    "Quantity": 0
                },
                "ConnectionAttempts": 3,
                "ConnectionTimeout": 10,
                "OriginShield": {
                    "Enabled": false
                }
            }
        ]
    },
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-$BUCKET",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"],
            "CachedMethods": {
                "Quantity": 2,
                "Items": ["GET", "HEAD"]
            }
        },
        "Compress": true,
        "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
        "OriginRequestPolicyId": "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf",
        "SmoothStreaming": false,
        "FunctionAssociations": {
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
    },
    "Aliases": {
        "Quantity": 1,
        "Items": ["$DOMAIN"]
    },
    "ViewerCertificate": {
        "ACMCertificateArn": "$CERT_ARN",
        "SSLSupportMethod": "sni-only",
        "MinimumProtocolVersion": "TLSv1.2_2021",
        "Certificate": "$CERT_ARN",
        "CertificateSource": "acm"
    },
    "PriceClass": "PriceClass_All",
    "HttpVersion": "http2and3",
    "IsIPV6Enabled": true
}
EOF

echo "✅ Configuration file created: cloudfront-config.json"
echo ""

# Create CloudFront distribution
echo "Creating CloudFront distribution (this may take 5-15 minutes)..."
echo ""

CF_OUTPUT=$(aws cloudfront create-distribution \
    --distribution-config file://cloudfront-config.json \
    --profile "$PROFILE" \
    --output json 2>&1)

if [ $? -eq 0 ]; then
    # Extract distribution details
    DISTRIBUTION_ID=$(echo "$CF_OUTPUT" | grep -o '"Id": "[^"]*"' | head -1 | cut -d'"' -f4)
    DISTRIBUTION_DOMAIN=$(echo "$CF_OUTPUT" | grep -o '"DomainName": "[^"]*"' | head-1 | cut -d'"' -f4)
    
    echo ""
    echo "================================================"
    echo "✅ CloudFront Distribution Created!"
    echo "================================================"
    echo ""
    echo "Distribution ID: $DISTRIBUTION_ID"
    echo "CloudFront Domain: $DISTRIBUTION_DOMAIN"
    echo ""
    
    # Save distribution info
    echo "$DISTRIBUTION_ID" > distribution-id.txt
    echo "$DISTRIBUTION_DOMAIN" > distribution-domain.txt
    
    echo "✅ Distribution ID saved to: distribution-id.txt"
    echo "✅ Distribution domain saved to: distribution-domain.txt"
    echo ""
    
    echo "Distribution Status: Deploying (InProgress)"
    echo ""
    echo "⏳ Deployment Progress:"
    echo "CloudFront distributions typically take 5-15 minutes to deploy globally"
    echo ""
    echo "Check deployment status:"
    echo "  aws cloudfront get-distribution --id $DISTRIBUTION_ID --profile $PROFILE --query 'Distribution.Status'"
    echo ""
    echo "Wait for status to change from 'InProgress' to 'Deployed' before proceeding"
    echo ""
    echo "Next steps:"
    echo "1. Wait for distribution to deploy (Status: Deployed)"
    echo "2. Run bash 07-update-bucket-policy.sh"
    echo "3. Run bash 08-create-route53-record.sh"
    
else
    echo ""
    echo "❌ Failed to create CloudFront distribution"
    echo ""
    echo "Error details:"
    echo "$CF_OUTPUT"
    exit 1
fi
