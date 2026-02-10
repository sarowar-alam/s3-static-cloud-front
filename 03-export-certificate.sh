#!/bin/bash

#############################################
# Export Let's Encrypt Certificate Files
# Prepares certificate for ACM import
# Domain: bmiostad.ostaddevops.click
#############################################

set -e  # Exit on any error

# Configuration
DOMAIN="bmiostad.ostaddevops.click"
CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
EXPORT_DIR="./ssl-certs"

echo "================================================"
echo "Exporting SSL Certificate Files"
echo "================================================"
echo ""

# Create export directory
mkdir -p "$EXPORT_DIR"
echo "Export directory: $EXPORT_DIR"
echo ""

# Check if certificates exist
if [ ! -d "$CERT_DIR" ]; then
    echo "❌ ERROR: Certificate directory not found: $CERT_DIR"
    echo "Please run 02-request-certificate.sh first"
    exit 1
fi

# Export certificate files
echo "Exporting certificate files..."

sudo cat "$CERT_DIR/cert.pem" > "$EXPORT_DIR/cert.pem"
echo "✅ Exported: cert.pem"

sudo cat "$CERT_DIR/privkey.pem" > "$EXPORT_DIR/privkey.pem"
echo "✅ Exported: privkey.pem"

sudo cat "$CERT_DIR/chain.pem" > "$EXPORT_DIR/chain.pem"
echo "✅ Exported: chain.pem"

sudo cat "$CERT_DIR/fullchain.pem" > "$EXPORT_DIR/fullchain.pem"
echo "✅ Exported: fullchain.pem"

# Set proper permissions
chmod 600 "$EXPORT_DIR/privkey.pem"
chmod 644 "$EXPORT_DIR/cert.pem"
chmod 644 "$EXPORT_DIR/chain.pem"
chmod 644 "$EXPORT_DIR/fullchain.pem"

echo ""
echo "================================================"
echo "✅ Certificate Export Complete!"
echo "================================================"
echo ""
echo "Exported files in $EXPORT_DIR:"
ls -lh "$EXPORT_DIR/"
echo ""
echo "Certificate details:"
openssl x509 -in "$EXPORT_DIR/cert.pem" -noout -subject -issuer -dates
echo ""
echo "Next step: Run bash 04-import-to-acm.sh"
echo ""
echo "⚠️  SECURITY NOTE:"
echo "Private key file contains sensitive data. Keep it secure!"
echo "Do not commit privkey.pem to version control!"
echo ""
