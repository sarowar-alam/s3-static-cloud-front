#!/bin/bash

#############################################
# Install Certbot and Route53 Plugin
# For Ubuntu 24.04 LTS
# This script installs Certbot and the DNS Route53 plugin
#############################################

set -e  # Exit on any error

echo "================================================"
echo "Installing Certbot and Route53 Plugin"
echo "================================================"

# Update package list
echo "Updating package list..."
sudo apt update

# Install Certbot and Route53 plugin
echo "Installing Certbot with Route53 DNS plugin..."
sudo apt install -y certbot python3-certbot-dns-route53

# Verify installation
echo ""
echo "Verifying installation..."
certbot --version

echo ""
echo "================================================"
echo "✅ Installation Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Configure AWS credentials: ~/.aws/credentials"
echo "2. Ensure IAM user has Route53 permissions:"
echo "   - route53:ChangeResourceRecordSets"
echo "   - route53:GetChange"
echo "   - route53:ListHostedZones"
echo "3. Run: bash 02-request-certificate.sh"
echo ""
