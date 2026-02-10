#!/bin/bash

#############################################
# Import Let's Encrypt Certificate to AWS ACM
# Region: us-east-1 (required for CloudFront)
# Domain: bmiostad.ostaddevops.click
#############################################

set -e  # Exit on any error

# Configuration
DOMAIN="bmiostad.ostaddevops.click"
AWS_PROFILE="sarowar-ostad"
AWS_REGION="us-east-1"
CERT_DIR="./ssl-certs"

echo "================================================"
echo "Importing Certificate to AWS ACM"
echo "================================================"
echo ""
echo "Domain: $DOMAIN"
echo "Region: $AWS_REGION (required for CloudFront)"
echo "Profile: $AWS_PROFILE"
echo ""

# Check if certificate files exist
if [ ! -f "$CERT_DIR/cert.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ] || [ ! -f "$CERT_DIR/chain.pem" ]; then
    echo "❌ ERROR: Certificate files not found in $CERT_DIR"
    echo "Please run 03-export-certificate.sh first"
    exit 1
fi

# Verify AWS credentials
echo "Verifying AWS credentials..."
aws sts get-caller-identity --profile "$AWS_PROFILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ AWS credentials verified"
else
    echo "❌ ERROR: AWS credentials not configured for profile $AWS_PROFILE"
    exit 1
fi

# Import certificate to ACM
echo ""
echo "Importing certificate to ACM in $AWS_REGION..."
echo ""

CERT_ARN=$(aws acm import-certificate \
    --certificate fileb://"$CERT_DIR/cert.pem" \
    --certificate-chain fileb://"$CERT_DIR/chain.pem" \
    --private-key fileb://"$CERT_DIR/privkey.pem" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" \
    --tags "Key=Domain,Value=$DOMAIN" "Key=ManagedBy,Value=Certbot" "Key=Project,Value=OstadDevOps" \
    --query 'CertificateArn' \
    --output text)

if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "✅ Certificate Successfully Imported to ACM!"
    echo "================================================"
    echo ""
    echo "Certificate ARN:"
    echo "$CERT_ARN"
    echo ""
    
    # Save ARN to file for later use
    echo "$CERT_ARN" > certificate-arn.txt
    echo "✅ Certificate ARN saved to: certificate-arn.txt"
    echo ""
    
    # Display certificate details
    echo "Certificate details:"
    aws acm describe-certificate \
        --certificate-arn "$CERT_ARN" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --query 'Certificate.[DomainName,Status,NotAfter,Issuer]' \
        --output table
    
    echo ""
    echo "⚠️  IMPORTANT REMINDERS:"
    echo "1. Let's Encrypt certificates expire in 90 days"
    echo "2. You must renew and re-import before expiration"
    echo "3. Set a calendar reminder for 60 days from now"
    echo "4. Use the certificate-arn.txt file for CloudFront setup"
    echo ""
    echo "Next step: Run bash 05-create-s3-bucket.sh"
else
    echo ""
    echo "❌ Certificate import failed"
    exit 1
fi
