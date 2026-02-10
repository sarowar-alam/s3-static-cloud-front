#!/bin/bash

#############################################
# Request Let's Encrypt Certificate via Certbot
# Using DNS-01 challenge with Route53
# Domain: bmiostad.ostaddevops.click
# Hosted Zone: ostaddevops.click (Z1019653XLWIJ02C53P5)
#############################################

set -e  # Exit on any error

# Configuration
DOMAIN="bmiostad.ostaddevops.click"
EMAIL="your-email@example.com"  # ⚠️ UPDATE THIS WITH YOUR EMAIL
AWS_PROFILE="sarowar-ostad"

echo "================================================"
echo "Requesting SSL Certificate for: $DOMAIN"
echo "================================================"
echo ""
echo "⚠️  IMPORTANT: Update EMAIL variable in this script before running!"
echo ""

# Check if email is still default
if [ "$EMAIL" == "your-email@example.com" ]; then
    echo "❌ ERROR: Please update the EMAIL variable in this script"
    exit 1
fi

# Verify AWS credentials
echo "Checking AWS credentials for profile: $AWS_PROFILE"
export AWS_PROFILE=$AWS_PROFILE
aws sts get-caller-identity > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ AWS credentials verified"
else
    echo "❌ ERROR: AWS credentials not configured for profile $AWS_PROFILE"
    exit 1
fi

# Request certificate using Certbot with Route53 DNS challenge
echo ""
echo "Requesting certificate from Let's Encrypt..."
echo "This will automatically create DNS TXT records in Route53 for validation"
echo ""

sudo certbot certonly \
    --dns-route53 \
    --agree-tos \
    --email "$EMAIL" \
    --non-interactive \
    -d "$DOMAIN"

# Check if certificate was issued
if [ $? -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "✅ Certificate Successfully Issued!"
    echo "================================================"
    echo ""
    echo "Certificate location: /etc/letsencrypt/live/$DOMAIN/"
    echo ""
    echo "Files:"
    echo "  - cert.pem       : Certificate"
    echo "  - privkey.pem    : Private key"
    echo "  - chain.pem      : Certificate chain"
    echo "  - fullchain.pem  : Full certificate chain"
    echo ""
    echo "Certificate expires in 90 days"
    echo ""
    echo "Next step: Run bash 03-export-certificate.sh"
else
    echo ""
    echo "❌ Certificate request failed"
    exit 1
fi
