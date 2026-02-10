#!/bin/bash

#############################################
# Renew Let's Encrypt Certificate and Re-import to ACM
# Run this script every 60-80 days
# Domain: bmiostad.ostaddevops.click
#############################################

set -e  # Exit on any error

# Configuration
DOMAIN="bmiostad.ostaddevops.click"
AWS_PROFILE="sarowar-ostad"
AWS_REGION="us-east-1"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
EXPORT_DIR="./ssl-certs"

echo "================================================"
echo "Certificate Renewal and Re-import Process"
echo "================================================"
echo ""
echo "Domain: $DOMAIN"
echo "AWS Region: $AWS_REGION"
echo "AWS Profile: $AWS_PROFILE"
echo ""

# Check if certificate exists
if [ ! -d "$CERT_DIR" ]; then
    echo "❌ ERROR: Certificate directory not found: $CERT_DIR"
    echo "Please run the initial setup first (scripts 01-04)"
    exit 1
fi

# Display current certificate expiry
echo "Current certificate details:"
sudo openssl x509 -in "$CERT_DIR/cert.pem" -noout -subject -issuer -dates
echo ""

# Step 1: Renew certificate with Certbot
echo "================================================"
echo "Step 1: Renewing Certificate with Certbot"
echo "================================================"
echo ""

echo "Running certificate renewal..."
sudo certbot renew --force-renewal

if [ $? -eq 0 ]; then
    echo "✅ Certificate renewed successfully"
else
    echo "❌ Certificate renewal failed"
    exit 1
fi

# Step 2: Export renewed certificate
echo ""
echo "================================================"
echo "Step 2: Exporting Renewed Certificate"
echo "================================================"
echo ""

mkdir -p "$EXPORT_DIR"

sudo cat "$CERT_DIR/cert.pem" > "$EXPORT_DIR/cert.pem"
sudo cat "$CERT_DIR/privkey.pem" > "$EXPORT_DIR/privkey.pem"
sudo cat "$CERT_DIR/chain.pem" > "$EXPORT_DIR/chain.pem"
sudo cat "$CERT_DIR/fullchain.pem" > "$EXPORT_DIR/fullchain.pem"

chmod 600 "$EXPORT_DIR/privkey.pem"
chmod 644 "$EXPORT_DIR/cert.pem"
chmod 644 "$EXPORT_DIR/chain.pem"
chmod 644 "$EXPORT_DIR/fullchain.pem"

echo "✅ Certificate files exported to: $EXPORT_DIR"
echo ""

# Display renewed certificate details
echo "Renewed certificate details:"
openssl x509 -in "$EXPORT_DIR/cert.pem" -noout -subject -issuer -dates
echo ""

# Step 3: Get current certificate ARN from ACM
echo "================================================"
echo "Step 3: Getting Current Certificate ARN"
echo "================================================"
echo ""

if [ -f "certificate-arn.txt" ]; then
    OLD_CERT_ARN=$(cat certificate-arn.txt)
    echo "Previous certificate ARN: $OLD_CERT_ARN"
    echo ""
else
    echo "⚠️  Warning: certificate-arn.txt not found"
    OLD_CERT_ARN=""
fi

# Step 4: Re-import certificate to ACM (replaces existing)
echo "================================================"
echo "Step 4: Re-importing Certificate to ACM"
echo "================================================"
echo ""

if [ ! -z "$OLD_CERT_ARN" ]; then
    echo "Re-importing to existing certificate ARN..."
    
    NEW_CERT_ARN=$(aws acm import-certificate \
        --certificate-arn "$OLD_CERT_ARN" \
        --certificate fileb://"$EXPORT_DIR/cert.pem" \
        --certificate-chain fileb://"$EXPORT_DIR/chain.pem" \
        --private-key fileb://"$EXPORT_DIR/privkey.pem" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --query 'CertificateArn' \
        --output text)
    
    if [ $? -eq 0 ]; then
        echo "✅ Certificate re-imported successfully"
        echo "Certificate ARN: $NEW_CERT_ARN"
        echo ""
        echo "⚠️  CloudFront will automatically use the renewed certificate"
        echo "   (same ARN, no CloudFront changes needed)"
    else
        echo "❌ Failed to re-import certificate"
        exit 1
    fi
else
    echo "Importing as new certificate..."
    
    NEW_CERT_ARN=$(aws acm import-certificate \
        --certificate fileb://"$EXPORT_DIR/cert.pem" \
        --certificate-chain fileb://"$EXPORT_DIR/chain.pem" \
        --private-key fileb://"$EXPORT_DIR/privkey.pem" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --tags "Key=Domain,Value=$DOMAIN" "Key=ManagedBy,Value=Certbot" "Key=Project,Value=OstadDevOps" \
        --query 'CertificateArn' \
        --output text)
    
    if [ $? -eq 0 ]; then
        echo "✅ Certificate imported successfully"
        echo "Certificate ARN: $NEW_CERT_ARN"
        echo "$NEW_CERT_ARN" > certificate-arn.txt
        echo ""
        echo "⚠️  You will need to update CloudFront distribution to use new certificate"
        echo "   Run: aws cloudfront update-distribution --id \$(cat distribution-id.txt) ..."
    else
        echo "❌ Failed to import certificate"
        exit 1
    fi
fi

# Step 5: Verify certificate in ACM
echo ""
echo "================================================"
echo "Step 5: Verifying Certificate in ACM"
echo "================================================"
echo ""

aws acm describe-certificate \
    --certificate-arn "$NEW_CERT_ARN" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE" \
    --query 'Certificate.[DomainName,Status,NotBefore,NotAfter,Issuer]' \
    --output table

echo ""
echo "================================================"
echo "✅ Certificate Renewal Complete!"
echo "================================================"
echo ""
echo "Summary:"
echo "1. ✅ Certificate renewed with Certbot"
echo "2. ✅ Certificate files exported"
echo "3. ✅ Certificate re-imported to ACM"
echo "4. ✅ CloudFront will use renewed certificate automatically"
echo ""
echo "Next renewal due: ~90 days from now"
echo ""
echo "📅 Set a reminder to run this script again in 60 days"
echo ""
echo "To test your website:"
echo "  curl -I https://$DOMAIN"
echo "  openssl s_client -connect $DOMAIN:443 -servername $DOMAIN | grep 'Verify return code'"
echo ""
