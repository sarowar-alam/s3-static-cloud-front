#!/bin/bash

#############################################
# Create CloudFront Origin Access Control (OAC)
# For secure S3 bucket access
# Bucket: ostad-devops-batch-10
#############################################

set -e  # Exit on any error

# Configuration
BUCKET="ostad-devops-batch-10"
OAC_NAME="ostad-devops-s3-oac"
DESCRIPTION="Origin Access Control for $BUCKET"
PROFILE="sarowar-ostad"
REGION="us-east-1"  # CloudFront is global but API calls go to us-east-1

echo "================================================"
echo "Creating CloudFront Origin Access Control (OAC)"
echo "================================================"
echo ""
echo "OAC Name: $OAC_NAME"
echo "S3 Bucket: $BUCKET"
echo "Profile: $PROFILE"
echo ""

# Verify AWS credentials
echo "Verifying AWS credentials..."
aws sts get-caller-identity --profile "$PROFILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ AWS credentials verified"
else
    echo "❌ ERROR: AWS credentials not configured for profile $PROFILE"
    exit 1
fi

# Create OAC
echo ""
echo "Creating Origin Access Control..."
echo ""

OAC_OUTPUT=$(aws cloudfront create-origin-access-control \
    --origin-access-control-config "{
        \"Name\": \"$OAC_NAME\",
        \"Description\": \"$DESCRIPTION\",
        \"SigningProtocol\": \"sigv4\",
        \"SigningBehavior\": \"always\",
        \"OriginAccessControlOriginType\": \"s3\"
    }" \
    --profile "$PROFILE" \
    --output json 2>&1)

if [ $? -eq 0 ]; then
    # Extract OAC ID from output
    OAC_ID=$(echo "$OAC_OUTPUT" | grep -o '"Id": "[^"]*"' | head -1 | cut -d'"' -f4)
    
    echo ""
    echo "================================================"
    echo "✅ Origin Access Control Created Successfully!"
    echo "================================================"
    echo ""
    echo "OAC ID: $OAC_ID"
    echo ""
    
    # Save OAC ID to file
    echo "$OAC_ID" > oac-id.txt
    echo "✅ OAC ID saved to: oac-id.txt"
    echo ""
    
    # Display full OAC details
    echo "OAC Details:"
    echo "$OAC_OUTPUT" | grep -E '"Id"|"Name"|"SigningProtocol"|"SigningBehavior"'
    echo ""
    echo "Next step: Run bash 06-create-cloudfront.sh"
    
else
    echo ""
    echo "❌ Failed to create Origin Access Control"
    echo ""
    echo "Error details:"
    echo "$OAC_OUTPUT"
    echo ""
    
    # Check if OAC already exists
    if echo "$OAC_OUTPUT" | grep -q "OriginAccessControlAlreadyExists"; then
        echo "⚠️  OAC with name '$OAC_NAME' already exists"
        echo ""
        echo "Fetching existing OAC ID..."
        
        # List OACs and find the matching one
        EXISTING_OAC=$(aws cloudfront list-origin-access-controls \
            --profile "$PROFILE" \
            --query "OriginAccessControlList.Items[?Name=='$OAC_NAME'].Id | [0]" \
            --output text)
        
        if [ ! -z "$EXISTING_OAC" ] && [ "$EXISTING_OAC" != "None" ]; then
            echo "$EXISTING_OAC" > oac-id.txt
            echo "✅ Found existing OAC ID: $EXISTING_OAC"
            echo "✅ Saved to: oac-id.txt"
            echo ""
            echo "You can proceed to the next step: bash 06-create-cloudfront.sh"
        else
            echo "❌ Could not retrieve existing OAC ID"
            exit 1
        fi
    else
        exit 1
    fi
fi
