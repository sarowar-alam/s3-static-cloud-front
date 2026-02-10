# Static Website with AWS S3, CloudFront, SSL & Route53

Complete setup for hosting a static website on AWS with:
- **S3 Bucket** (ap-south-1) - Private storage
- **CloudFront CDN** - Global content delivery with HTTPS
- **Let's Encrypt SSL** - Free SSL certificate via Certbot
- **Route53 DNS** - Custom domain routing

## 🌐 Project Details

- **Domain**: bmiostad.ostaddevops.click
- **S3 Bucket**: ostad-devops-batch-10 (ap-south-1)
- **Hosted Zone**: ostaddevops.click (Z1019653XLWIJ02C53P5)
- **AWS Profile**: sarowar-ostad

---

## 📋 Prerequisites

### On Ubuntu 24.04 (for Certbot)
- Ubuntu 24.04 LTS
- Root or sudo access
- AWS CLI installed and configured

### AWS Prerequisites
- AWS Account (ID: 388779989543)
- AWS CLI configured with profile `sarowar-ostad`
- IAM user with permissions for:
  - S3 (bucket creation, policy management)
  - CloudFront (distribution creation, OAC)
  - ACM (certificate import)
  - Route53 (record management, DNS validation)
  - STS (identity verification)

### Domain Prerequisites
- Route53 hosted zone: ostaddevops.click
- Domain must be configured to use Route53 nameservers

---

## 🚀 Setup Instructions

### Phase 1: SSL Certificate (Ubuntu 24.04)

Run these scripts on **Ubuntu 24.04**:

#### 1️⃣ Install Certbot
```bash
bash 01-install-certbot.sh
```
- Installs Certbot and Route53 DNS plugin
- Verifies installation

#### 2️⃣ Request Certificate
```bash
# IMPORTANT: Edit script and update EMAIL variable first!
bash 02-request-certificate.sh
```
- Requests Let's Encrypt certificate for bmiostad.ostaddevops.click
- Uses Route53 DNS-01 challenge (automatic validation)
- Certificate stored in `/etc/letsencrypt/live/bmiostad.ostaddevops.click/`

#### 3️⃣ Export Certificate
```bash
bash 03-export-certificate.sh
```
- Exports certificate files to `./ssl-certs/` directory
- Files: cert.pem, privkey.pem, chain.pem, fullchain.pem

#### 4️⃣ Import to ACM
```bash
bash 04-import-to-acm.sh
```
- Imports certificate to AWS ACM in us-east-1 (required for CloudFront)
- Saves certificate ARN to `certificate-arn.txt`

---

### Phase 2: AWS Infrastructure

Run these scripts on **any machine** with AWS CLI configured:

#### 5️⃣ Create S3 Bucket
```bash
bash 05-create-s3-bucket.sh
```
- Creates private S3 bucket: ostad-devops-batch-10 in ap-south-1
- Uploads index.html and error.html
- Enables static website hosting
- **Bucket remains private** (no public access)

#### 6️⃣ Create CloudFront OAC
```bash
bash 06-create-cloudfront-oac.sh
```
- Creates Origin Access Control (OAC) for secure S3 access
- Saves OAC ID to `oac-id.txt`

#### 6️⃣ Create CloudFront Distribution
```bash
bash 06-create-cloudfront.sh
```
- Creates CloudFront distribution with:
  - S3 origin (ostad-devops-batch-10)
  - SSL certificate from ACM
  - Custom domain (bmiostad.ostaddevops.click)
  - HTTPS redirect (HTTP → HTTPS)
  - Custom error page (404 → error.html)
  - Compression enabled
  - HTTP/2 and HTTP/3 support
- Saves distribution ID to `distribution-id.txt`
- Saves CloudFront domain to `distribution-domain.txt`
- ⏳ **Takes 5-15 minutes to deploy**

#### 7️⃣ Update S3 Bucket Policy
```bash
bash 07-update-bucket-policy.sh
```
- Updates bucket policy to allow CloudFront OAC access
- Bucket remains private to public
- Only CloudFront distribution can access objects

#### 8️⃣ Create Route53 DNS Record
```bash
bash 08-create-route53-record.sh
```
- Creates A and AAAA records in Route53
- Points bmiostad.ostaddevops.click to CloudFront distribution
- Uses Route53 Alias records (no charge)
- ⏳ **DNS propagation: 5-60 minutes**

---

## ✅ Verification

After DNS propagation (5-60 minutes), test your website:

### Test HTTPS Access
```bash
curl -I https://bmiostad.ostaddevops.click
```

### Test HTTP Redirect
```bash
curl -I http://bmiostad.ostaddevops.click
```

### Test SSL Certificate
```bash
openssl s_client -connect bmiostad.ostaddevops.click:443 -servername bmiostad.ostaddevops.click
```

### Test DNS Resolution
```bash
nslookup bmiostad.ostaddevops.click
dig bmiostad.ostaddevops.click
```

### Browser Test
Open in browser: https://bmiostad.ostaddevops.click

---

## 🔄 Certificate Renewal

Let's Encrypt certificates **expire every 90 days**.

### Automated Renewal (Every 60-80 Days)
```bash
bash 09-renew-certificate.sh
```

This script:
1. Renews certificate with Certbot
2. Exports renewed certificate
3. Re-imports to ACM (same ARN)
4. CloudFront automatically uses renewed certificate

### Set Calendar Reminder
📅 **Set a reminder for 60 days from today** to run the renewal script.

---

## 📁 Project Structure

```
static-site/
├── 01-install-certbot.sh           # Install Certbot on Ubuntu 24
├── 02-request-certificate.sh       # Request Let's Encrypt certificate
├── 03-export-certificate.sh        # Export certificate files
├── 04-import-to-acm.sh            # Import to AWS ACM
├── 05-create-s3-bucket.sh         # Create private S3 bucket
├── 06-create-cloudfront-oac.sh    # Create CloudFront OAC
├── 06-create-cloudfront.sh        # Create CloudFront distribution
├── 07-update-bucket-policy.sh     # Update S3 bucket policy
├── 08-create-route53-record.sh    # Create Route53 DNS record
├── 09-renew-certificate.sh        # Renew certificate (run every 60 days)
├── create-bucket.sh               # Updated S3 bucket script
├── index.html                     # Website homepage
├── error.html                     # 404 error page
├── README.md                      # This file
└── .gitignore                     # Git ignore rules
```

### Generated Files (Not in Git)
```
ssl-certs/                         # Certificate files (sensitive)
├── cert.pem
├── privkey.pem
├── chain.pem
└── fullchain.pem
certificate-arn.txt               # ACM certificate ARN
oac-id.txt                       # CloudFront OAC ID
distribution-id.txt              # CloudFront distribution ID
distribution-domain.txt          # CloudFront domain name
cloudfront-config.json           # CloudFront configuration
bucket-policy.json               # S3 bucket policy
route53-change.json              # Route53 change batch
policy.json                      # Old bucket policy (legacy)
```

---

## 🔒 Security Best Practices

1. **Private S3 Bucket**: Only accessible via CloudFront OAC
2. **HTTPS Only**: HTTP requests automatically redirect to HTTPS
3. **TLS 1.2+**: Minimum TLS version enforced
4. **No Public Access**: S3 Block Public Access enabled
5. **Least Privilege**: Bucket policy allows only specific CloudFront distribution

---

## 🔧 Updating Website Content

### Upload New Files
```bash
aws s3 cp newfile.html s3://ostad-devops-batch-10/ \
  --content-type "text/html; charset=utf-8" \
  --profile sarowar-ostad
```

### Invalidate CloudFront Cache
```bash
aws cloudfront create-invalidation \
  --distribution-id $(cat distribution-id.txt) \
  --paths "/*" \
  --profile sarowar-ostad
```

---

## 📊 Monitoring & Management

### Check CloudFront Distribution Status
```bash
aws cloudfront get-distribution \
  --id $(cat distribution-id.txt) \
  --profile sarowar-ostad \
  --query 'Distribution.Status'
```

### Check Certificate Expiry
```bash
aws acm describe-certificate \
  --certificate-arn $(cat certificate-arn.txt) \
  --region us-east-1 \
  --profile sarowar-ostad \
  --query 'Certificate.NotAfter'
```

### List CloudFront Distributions
```bash
aws cloudfront list-distributions \
  --profile sarowar-ostad \
  --query 'DistributionList.Items[*].[Id,DomainName,Status]' \
  --output table
```

---

## ⚠️ Important Notes

1. **Certificate Region**: ACM certificates for CloudFront **must** be in us-east-1
2. **S3 Region**: Bucket can be in any region (we use ap-south-1)
3. **Certificate Expiry**: Let's Encrypt certificates expire in 90 days
4. **Renewal Process**: Must renew and re-import certificate before expiry
5. **DNS Propagation**: Can take 5-60 minutes globally
6. **CloudFront Deployment**: Takes 5-15 minutes for changes to propagate
7. **Sensitive Files**: Never commit `ssl-certs/` or `privkey.pem` to version control

---

## 🆘 Troubleshooting

### Certificate Request Fails
- Verify AWS credentials are configured
- Check Route53 hosted zone exists and is accessible
- Ensure IAM user has Route53 permissions

### CloudFront Distribution Creation Fails
- Verify certificate ARN is in us-east-1
- Check OAC ID is correct
- Ensure domain matches certificate

### Website Not Accessible
- Wait for CloudFront deployment (5-15 minutes)
- Wait for DNS propagation (5-60 minutes)
- Verify Route53 record created correctly
- Check bucket policy allows CloudFront access

### SSL Certificate Invalid
- Verify certificate imported to us-east-1
- Check CloudFront using correct certificate ARN
- Wait for CloudFront deployment to complete

---

## 💰 Cost Estimate

- **S3 Storage**: ~$0.023/GB/month
- **CloudFront**: First 1TB free/month, then $0.085/GB
- **Route53 Hosted Zone**: $0.50/month
- **ACM Certificate**: **FREE** (imported certificates)
- **Let's Encrypt**: **FREE**

**Total Estimated Monthly Cost**: < $5 for low-traffic sites

---

## 📚 Resources

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [AWS ACM Documentation](https://docs.aws.amazon.com/acm/)
- [AWS Route53 Documentation](https://docs.aws.amazon.com/route53/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://certbot.eff.org/docs/)

---

## 📝 License

This project setup is for educational purposes as part of Ostad DevOps Batch-08.

---

## 👨‍💻 Author

**Ostad DevOps Batch-08 - Module 01 - Class 02**

For questions or issues, contact your instructor or refer to AWS documentation.
