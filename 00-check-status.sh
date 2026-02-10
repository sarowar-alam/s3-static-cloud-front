#!/bin/bash

#############################################
# Setup Status Checker
# Verifies which steps have been completed
# and what remains to be done
#############################################

# Configuration
DOMAIN="bmiostad.ostaddevops.click"
BUCKET="ostad-devops-batch-10"
HOSTED_ZONE_ID="Z1019653XLWIJ02C53P5"
PROFILE="sarowar-ostad"

echo "================================================"
echo "AWS Static Website Setup - Status Checker"
echo "================================================"
echo ""
echo "Domain: $DOMAIN"
echo "Bucket: $BUCKET"
echo "Date: $(date)"
echo ""
echo "================================================"
echo "Setup Progress"
echo "================================================"
echo ""

# Track completed steps
COMPLETED_STEPS=0
TOTAL_STEPS=9

# Step 1: Check Certbot installation
echo -n "Step 1: Certbot Installation............... "
if command -v certbot &> /dev/null; then
    echo "✅ COMPLETE ($(certbot --version 2>&1 | head -1))"
    ((COMPLETED_STEPS++))
else
    echo "❌ NOT COMPLETE - Run: bash 01-install-certbot.sh"
fi

# Step 2: Check certificate request
echo -n "Step 2: SSL Certificate Request............ "
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    EXPIRY=$(sudo openssl x509 -in "/etc/letsencrypt/live/$DOMAIN/cert.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
    echo "✅ COMPLETE (Expires: $EXPIRY)"
    ((COMPLETED_STEPS++))
else
    echo "❌ NOT COMPLETE - Run: bash 02-request-certificate.sh"
fi

# Step 3: Check certificate export
echo -n "Step 3: Certificate Export................. "
if [ -f "ssl-certs/cert.pem" ] && [ -f "ssl-certs/privkey.pem" ]; then
    echo "✅ COMPLETE"
    ((COMPLETED_STEPS++))
else
    echo "❌ NOT COMPLETE - Run: bash 03-export-certificate.sh"
fi

# Step 4: Check ACM import
echo -n "Step 4: ACM Certificate Import............. "
if [ -f "certificate-arn.txt" ]; then
    CERT_ARN=$(cat certificate-arn.txt)
    echo "✅ COMPLETE ($CERT_ARN)"
    ((COMPLETED_STEPS++))
else
    echo "❌ NOT COMPLETE - Run: bash 04-import-to-acm.sh"
fi

# Step 5: Check S3 bucket
echo -n "Step 5: S3 Bucket Creation................. "
BUCKET_CHECK=$(aws s3 ls s3://"$BUCKET" --profile "$PROFILE" 2>&1)
if [ $? -eq 0 ]; then
    echo "✅ COMPLETE"
    ((COMPLETED_STEPS++))
else
    echo "❌ NOT COMPLETE - Run: bash 05-create-s3-bucket.sh"
fi

# Step 6a: Check OAC
echo -n "Step 6a: CloudFront OAC.................... "
if [ -f "oac-id.txt" ]; then
    OAC_ID=$(cat oac-id.txt)
    echo "✅ COMPLETE ($OAC_ID)"
    ((COMPLETED_STEPS++))
else
    echo "❌ NOT COMPLETE - Run: bash 06-create-cloudfront-oac.sh"
fi

# Step 6b: Check CloudFront distribution
echo -n "Step 6b: CloudFront Distribution........... "
if [ -f "distribution-id.txt" ]; then
    DIST_ID=$(cat distribution-id.txt)
    DIST_STATUS=$(aws cloudfront get-distribution --id "$DIST_ID" --profile "$PROFILE" --query 'Distribution.Status' --output text 2>/dev/null)
    if [ ! -z "$DIST_STATUS" ]; then
        echo "✅ COMPLETE (Status: $DIST_STATUS)"
        ((COMPLETED_STEPS++))
    else
        echo "⚠️  FILE EXISTS but distribution not found"
    fi
else
    echo "❌ NOT COMPLETE - Run: bash 06-create-cloudfront.sh"
fi

# Step 7: Check bucket policy
echo -n "Step 7: S3 Bucket Policy................... "
POLICY_CHECK=$(aws s3api get-bucket-policy --bucket "$BUCKET" --profile "$PROFILE" 2>&1)
if [ $? -eq 0 ]; then
    if echo "$POLICY_CHECK" | grep -q "cloudfront.amazonaws.com"; then
        echo "✅ COMPLETE (CloudFront OAC access granted)"
        ((COMPLETED_STEPS++))
    else
        echo "⚠️  Policy exists but not configured for CloudFront"
    fi
else
    echo "❌ NOT COMPLETE - Run: bash 07-update-bucket-policy.sh"
fi

# Step 8: Check Route53 record
echo -n "Step 8: Route53 DNS Record................. "
RECORD_CHECK=$(aws route53 list-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --profile "$PROFILE" \
    --query "ResourceRecordSets[?Name=='$DOMAIN.']" \
    --output text 2>&1)
if [ $? -eq 0 ] && [ ! -z "$RECORD_CHECK" ]; then
    echo "✅ COMPLETE"
    ((COMPLETED_STEPS++))
else
    echo "❌ NOT COMPLETE - Run: bash 08-create-route53-record.sh"
fi

echo ""
echo "================================================"
echo "Overall Progress: $COMPLETED_STEPS/$TOTAL_STEPS steps completed"
echo "================================================"
echo ""

# Calculate percentage
PERCENTAGE=$((COMPLETED_STEPS * 100 / TOTAL_STEPS))
echo "Progress: $PERCENTAGE%"
echo ""

if [ $COMPLETED_STEPS -eq $TOTAL_STEPS ]; then
    echo "🎉 Setup is COMPLETE!"
    echo ""
    echo "Your website should be accessible at:"
    echo "  https://$DOMAIN"
    echo ""
    echo "Verification commands:"
    echo "  curl -I https://$DOMAIN"
    echo "  nslookup $DOMAIN"
    echo ""
    echo "⚠️  Remember to renew SSL certificate in 60 days!"
    echo "   Run: bash 09-renew-certificate.sh"
elif [ $COMPLETED_STEPS -ge 4 ]; then
    echo "✅ Phase 1 (SSL Certificate) complete!"
    echo "📍 Continue with Phase 2 (AWS Infrastructure)"
    echo ""
    echo "Next step: bash 05-create-s3-bucket.sh"
elif [ $COMPLETED_STEPS -ge 1 ]; then
    echo "📍 Phase 1 (SSL Certificate) in progress"
    echo ""
    if [ $COMPLETED_STEPS -eq 1 ]; then
        echo "Next step: bash 02-request-certificate.sh"
    elif [ $COMPLETED_STEPS -eq 2 ]; then
        echo "Next step: bash 03-export-certificate.sh"
    elif [ $COMPLETED_STEPS -eq 3 ]; then
        echo "Next step: bash 04-import-to-acm.sh"
    fi
else
    echo "📍 Getting started"
    echo ""
    echo "Run these scripts on Ubuntu 24.04:"
    echo "  bash 01-install-certbot.sh"
fi

echo ""
echo "================================================"
echo "Certificate Status"
echo "================================================"
echo ""

if [ -f "certificate-arn.txt" ]; then
    CERT_ARN=$(cat certificate-arn.txt)
    echo "Certificate ARN: $CERT_ARN"
    echo ""
    
    # Check certificate expiry in ACM
    CERT_INFO=$(aws acm describe-certificate \
        --certificate-arn "$CERT_ARN" \
        --region us-east-1 \
        --profile "$PROFILE" \
        --query 'Certificate.[Status,NotAfter]' \
        --output text 2>/dev/null)
    
    if [ ! -z "$CERT_INFO" ]; then
        STATUS=$(echo "$CERT_INFO" | awk '{print $1}')
        EXPIRY=$(echo "$CERT_INFO" | awk '{print $2}')
        
        echo "Status: $STATUS"
        echo "Expires: $EXPIRY"
        echo ""
        
        # Calculate days until expiry
        EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$EXPIRY" +%s 2>/dev/null)
        NOW_EPOCH=$(date +%s)
        DAYS_REMAINING=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
        
        if [ ! -z "$DAYS_REMAINING" ]; then
            echo "Days until expiry: $DAYS_REMAINING"
            
            if [ $DAYS_REMAINING -lt 30 ]; then
                echo ""
                echo "⚠️  WARNING: Certificate expires in less than 30 days!"
                echo "   Run: bash 09-renew-certificate.sh"
            elif [ $DAYS_REMAINING -lt 60 ]; then
                echo ""
                echo "📅 Reminder: Consider renewing certificate soon"
                echo "   Run: bash 09-renew-certificate.sh"
            fi
        fi
    fi
else
    echo "No certificate ARN found"
fi

echo ""
echo "================================================"
echo "Useful Commands"
echo "================================================"
echo ""
echo "Check CloudFront deployment status:"
echo "  aws cloudfront get-distribution --id \$(cat distribution-id.txt) --profile $PROFILE --query 'Distribution.Status'"
echo ""
echo "Test website:"
echo "  curl -I https://$DOMAIN"
echo ""
echo "Check DNS:"
echo "  nslookup $DOMAIN"
echo ""
echo "Invalidate CloudFront cache:"
echo "  aws cloudfront create-invalidation --distribution-id \$(cat distribution-id.txt) --paths '/*' --profile $PROFILE"
echo ""
