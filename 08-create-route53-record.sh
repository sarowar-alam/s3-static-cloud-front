#!/bin/bash

#############################################
# Create Route53 DNS Record
# Points custom domain to CloudFront distribution
# Domain: bmiostad.ostaddevops.click
# Hosted Zone: Z1019653XLWIJ02C53P5
#############################################

set -e  # Exit on any error

# Configuration
DOMAIN="bmiostad.ostaddevops.click"
HOSTED_ZONE_ID="Z1019653XLWIJ02C53P5"
PROFILE="sarowar-ostad"
CLOUDFRONT_HOSTED_ZONE="Z2FDTNDATAQYW2"  # Fixed ID for all CloudFront distributions

echo "================================================"
echo "Creating Route53 DNS Record"
echo "================================================"
echo ""

# Check required files
if [ ! -f "distribution-domain.txt" ]; then
    echo "❌ ERROR: distribution-domain.txt not found"
    echo "Please run 06-create-cloudfront.sh first"
    exit 1
fi

# Load CloudFront domain
CLOUDFRONT_DOMAIN=$(cat distribution-domain.txt)

echo "Domain: $DOMAIN"
echo "Hosted Zone ID: $HOSTED_ZONE_ID"
echo "CloudFront Domain: $CLOUDFRONT_DOMAIN"
echo ""

# Verify AWS credentials
echo "Verifying AWS credentials..."
aws sts get-caller-identity --profile "$PROFILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ AWS credentials verified"
else
    echo "❌ ERROR: AWS credentials not configured"
    exit 1
fi

# Verify hosted zone exists
echo ""
echo "Verifying Route53 hosted zone..."
ZONE_CHECK=$(aws route53 get-hosted-zone \
    --id "$HOSTED_ZONE_ID" \
    --profile "$PROFILE" \
    --query 'HostedZone.Name' \
    --output text 2>&1)

if [ $? -eq 0 ]; then
    echo "✅ Hosted zone verified: $ZONE_CHECK"
else
    echo "❌ ERROR: Could not access hosted zone $HOSTED_ZONE_ID"
    exit 1
fi

# Create Route53 change batch
echo ""
echo "Creating DNS record change batch..."

cat > route53-change.json <<EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$DOMAIN",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "$CLOUDFRONT_HOSTED_ZONE",
                    "DNSName": "$CLOUDFRONT_DOMAIN",
                    "EvaluateTargetHealth": false
                }
            }
        },
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$DOMAIN",
                "Type": "AAAA",
                "AliasTarget": {
                    "HostedZoneId": "$CLOUDFRONT_HOSTED_ZONE",
                    "DNSName": "$CLOUDFRONT_DOMAIN",
                    "EvaluateTargetHealth": false
                }
            }
        }
    ]
}
EOF

echo "✅ Change batch created: route53-change.json"
echo ""

# Apply Route53 changes
echo "Creating Route53 A and AAAA records (IPv4 and IPv6)..."
echo ""

CHANGE_OUTPUT=$(aws route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch file://route53-change.json \
    --profile "$PROFILE" \
    --output json 2>&1)

if [ $? -eq 0 ]; then
    CHANGE_ID=$(echo "$CHANGE_OUTPUT" | grep -o '"Id": "[^"]*"' | cut -d'"' -f4)
    
    echo ""
    echo "================================================"
    echo "✅ Route53 DNS Records Created!"
    echo "================================================"
    echo ""
    echo "Change ID: $CHANGE_ID"
    echo ""
    echo "DNS Records Created:"
    echo "  A    Record: $DOMAIN → $CLOUDFRONT_DOMAIN"
    echo "  AAAA Record: $DOMAIN → $CLOUDFRONT_DOMAIN (IPv6)"
    echo ""
    echo "Record Type: Alias (no charge for queries)"
    echo "Target: CloudFront Distribution"
    echo ""
    echo "⏳ DNS Propagation:"
    echo "- Route53 changes: 1-2 minutes"
    echo "- Global DNS propagation: 5-60 minutes (varies by ISP)"
    echo ""
    echo "Check propagation status:"
    echo "  aws route53 get-change --id $CHANGE_ID --profile $PROFILE --query 'ChangeInfo.Status'"
    echo ""
    echo "Test DNS resolution:"
    echo "  nslookup $DOMAIN"
    echo "  dig $DOMAIN"
    echo ""
    echo "================================================"
    echo "🎉 SETUP COMPLETE!"
    echo "================================================"
    echo ""
    echo "Your static website is now configured:"
    echo ""
    echo "✅ S3 Bucket: ostad-devops-batch-10 (ap-south-1) - Private"
    echo "✅ CloudFront: Global CDN with HTTPS"
    echo "✅ SSL Certificate: Let's Encrypt (imported to ACM)"
    echo "✅ Custom Domain: https://$DOMAIN"
    echo "✅ DNS: Route53 A and AAAA records"
    echo ""
    echo "Access your website:"
    echo "  https://$DOMAIN"
    echo ""
    echo "⚠️  IMPORTANT REMINDERS:"
    echo "1. Wait 5-15 minutes for DNS propagation"
    echo "2. SSL certificate expires in 90 days (Let's Encrypt)"
    echo "3. Set calendar reminder to renew certificate in 60 days"
    echo "4. Use 09-renew-certificate.sh for renewal process"
    echo ""
    echo "To update website content:"
    echo "  aws s3 cp yourfile.html s3://ostad-devops-batch-10/ --profile $PROFILE"
    echo "  aws cloudfront create-invalidation --distribution-id \$(cat distribution-id.txt) --paths '/*' --profile $PROFILE"
    echo ""
else
    echo ""
    echo "❌ Failed to create Route53 DNS records"
    echo ""
    echo "Error details:"
    echo "$CHANGE_OUTPUT"
    exit 1
fi
