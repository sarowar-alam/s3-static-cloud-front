# Manual Setup Guide: AWS Static Website with CloudFront & SSL

Complete step-by-step manual setup using AWS Console GUI and Ubuntu 24.04 terminal.

---

## 📋 Prerequisites

✅ **What You Already Have:**
- Route53 Hosted Zone with valid domain: `ostaddevops.click`
- Ubuntu 24.04 server with AWS SSM integrated
- AWS Console access
- Domain: `batch10.ostaddevops.click`

✅ **What You Need:**
- AWS Account with permissions for S3, CloudFront, ACM, Route53
- Email address for Let's Encrypt notifications
- 60-90 minutes of time

---

## 🎯 Architecture Overview

```
Internet
   ↓
Route53 DNS → CloudFront CDN (HTTPS) → S3 Bucket (Private)
              ↑
         SSL Certificate
      (Let's Encrypt via ACM)
```

---

# PHASE 1: SSL Certificate Setup (Ubuntu 24.04)

## Step 1: Connect to Ubuntu Server

### Via AWS Systems Manager (SSM)

1. **Open AWS Console** → Navigate to **EC2** or **Systems Manager**
2. Click **Session Manager** in left menu
3. Click **Start session**
4. Select your Ubuntu 24.04 instance
5. Click **Start session**

Alternatively, use SSH if configured:
```bash
ssh ubuntu@your-server-ip
```

---

## Step 2: Install Certbot with Route53 Plugin

Run these commands in your Ubuntu terminal:

```bash
# Update package list
sudo apt update

# Install Certbot and Route53 DNS plugin
sudo apt install -y certbot python3-certbot-dns-route53

# Verify installation
certbot --version
```

**Expected Output:**
```
certbot 2.x.x
```

---

## Step 3: Configure AWS Credentials on Ubuntu

Your server needs AWS credentials to create DNS records in Route53.

### Option A: If using IAM Instance Role (Recommended with SSM)

Your instance should already have permissions. Verify:

```bash
aws sts get-caller-identity
```

If this works, skip to Step 4.

### Option B: Configure AWS CLI manually

```bash
# Configure AWS credentials
aws configure

# Enter when prompted:
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-east-1
# Default output format: json
```

### Required IAM Permissions

Ensure the IAM role/user has these permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:GetChange"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/Z1019653XLWIJ02C53P5"
    }
  ]
}
```

---

## Step 4: Request SSL Certificate with Certbot

```bash
# Replace with your email and domain
sudo certbot certonly \
  --dns-route53 \
  --agree-tos \
  --email your-email@example.com \
  --non-interactive \
  -d batch10.ostaddevops.click
```

**What happens:**
1. Certbot contacts Let's Encrypt
2. Automatically creates a TXT record in Route53 for domain validation
3. Let's Encrypt verifies domain ownership
4. Issues certificate (valid for 90 days)
5. Stores certificate files in `/etc/letsencrypt/live/batch10.ostaddevops.click/`

**Expected Output:**
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/batch10.ostaddevops.click/fullchain.pem
Key is saved at: /etc/letsencrypt/live/batch10.ostaddevops.click/privkey.pem
```

---

## Step 5: Export Certificate Files

```bash
# Create export directory
mkdir -p ~/ssl-certs
cd ~/ssl-certs

# Export certificate files (requires sudo)
sudo cat /etc/letsencrypt/live/batch10.ostaddevops.click/cert.pem > cert.pem
sudo cat /etc/letsencrypt/live/batch10.ostaddevops.click/privkey.pem > privkey.pem
sudo cat /etc/letsencrypt/live/batch10.ostaddevops.click/chain.pem > chain.pem

# Set proper permissions
chmod 600 privkey.pem
chmod 644 cert.pem chain.pem

# Verify files
ls -lh ~/ssl-certs/
```

**Expected Files:**
- `cert.pem` - Your certificate
- `privkey.pem` - Private key (KEEP SECURE!)
- `chain.pem` - Certificate chain

---

## Step 6: View Certificate Details

```bash
# View certificate information
openssl x509 -in ~/ssl-certs/cert.pem -noout -text | head -20

# View expiration date
openssl x509 -in ~/ssl-certs/cert.pem -noout -dates
```

**Note the expiration date** - certificates expire in 90 days!

---

# PHASE 2: AWS Console Setup

## Step 7: Import Certificate to AWS ACM

### Navigate to AWS Certificate Manager

1. **Open AWS Console** → Search for **"Certificate Manager"** or **"ACM"**
2. **Important:** Change region to **us-east-1** (N. Virginia) in top-right corner
   - ⚠️ CloudFront REQUIRES certificates in us-east-1
3. Click **Import certificate**

### Import Certificate Details

4. **Certificate body** field:
   - Copy content from Ubuntu: `cat ~/ssl-certs/cert.pem`
   - Paste into field (including `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----`)

5. **Certificate private key** field:
   - Copy content from Ubuntu: `cat ~/ssl-certs/privkey.pem`
   - Paste into field (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`)

6. **Certificate chain** field:
   - Copy content from Ubuntu: `cat ~/ssl-certs/chain.pem`
   - Paste into field (including all certificate blocks)

7. Click **Next**

### Add Tags (Optional but Recommended)

8. Add tags:
   - Key: `Domain`, Value: `batch10.ostaddevops.click`
   - Key: `ManagedBy`, Value: `Certbot`
   - Key: `Project`, Value: `StaticWebsite`

9. Click **Review and import**
10. Click **Import**

### Save Certificate ARN

11. After import, you'll see the certificate listed
12. Click on the certificate
13. **Copy the ARN** (format: `arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID`)
14. **Save this ARN** - you'll need it for CloudFront!

**Example ARN:**
```
arn:aws:acm:us-east-1:388779989543:certificate/a1b2c3d4-1234-5678-90ab-cdef12345678
```

---

## Step 8: Create S3 Bucket

### Navigate to S3

1. **Open AWS Console** → Search for **"S3"**
2. Click **Create bucket**

### General Configuration

3. **Bucket name:** `ostad-devops-batch-10`
   - Bucket names must be globally unique
   - Use lowercase, numbers, hyphens only
   - If taken, use: `ostad-devops-batch-10-yourname`

4. **AWS Region:** Select **Asia Pacific (Mumbai) ap-south-1**
   - Choose region closest to your users

5. **Object Ownership:** Leave as default (ACLs disabled)

### Block Public Access Settings

6. **Block Public Access settings for this bucket:**
   - ✅ **Keep all boxes CHECKED** (Block all public access)
   - This is correct! CloudFront will access the bucket privately

7. **Bucket Versioning:** Disabled (optional, enable if you want version history)

8. **Default encryption:** Server-side encryption with Amazon S3 managed keys (SSE-S3)

9. Click **Create bucket**

### Upload Website Files

10. Click on your newly created bucket name
11. Click **Upload**
12. Click **Add files**
13. Select your `index.html` and `error.html` files
14. Click **Upload**

### Enable Static Website Hosting

15. In your bucket, click **Properties** tab
16. Scroll down to **Static website hosting**
17. Click **Edit**
18. Enable **Static website hosting**
19. **Hosting type:** Host a static website
20. **Index document:** `index.html`
21. **Error document:** `error.html`
22. Click **Save changes**

**Note:** Even though website hosting is enabled, the bucket is still private. Only CloudFront will be able to access it.

---

## Step 9: Create CloudFront Origin Access Control (OAC)

### Navigate to CloudFront

1. **Open AWS Console** → Search for **"CloudFront"**
2. In left sidebar, click **Origin access** (under Security section)
3. Click **Origin access control** tab
4. Click **Create control setting**

### Create OAC

5. **Name:** `ostad-devops-s3-oac`
6. **Description:** `Origin Access Control for ostad-devops-batch-10`
7. **Signing behavior:** Sign requests (recommended)
8. **Origin type:** S3
9. Click **Create**

10. **Copy the OAC ID** (format: `EXXXXXXXXXXXXXX`)
    - You'll need this for the next step

---

## Step 10: Create CloudFront Distribution

### Start Creating Distribution

1. Still in CloudFront console, click **Distributions** in left menu
2. Click **Create distribution**

### Origin Settings

3. **Origin domain:**
   - Click in the field
   - **DO NOT** select from dropdown (it shows website endpoint)
   - Manually type: `ostad-devops-batch-10.s3.ap-south-1.amazonaws.com`
   - Replace bucket name and region if different

4. **Name:** Leave auto-generated (like `ostad-devops-batch-10.s3.ap-south-1.amazonaws.com`)

5. **Origin path:** Leave blank

6. **Enable Origin Shield:** No

7. **Origin access:**
   - Select: **Origin access control settings (recommended)**
   - **Origin access control:** Select the OAC you created (`ostad-devops-s3-oac`)
   - Click **Create new OAC** if you didn't do Step 9

### Default Cache Behavior

8. **Path pattern:** Default (*)

9. **Compress objects automatically:** Yes

10. **Viewer protocol policy:** Redirect HTTP to HTTPS

11. **Allowed HTTP methods:** GET, HEAD

12. **Cache policy:** CachingOptimized (Recommended)

13. **Origin request policy:** CORS-S3Origin (Recommended for S3)

### Web Application Firewall (WAF)

14. **WAF:** Do not enable (costs extra, optional)

### Settings

15. **Price class:** Use all edge locations (best performance)
    - Or choose specific regions to reduce cost

16. **Alternate domain name (CNAME):**
    - Click **Add item**
    - Enter: `batch10.ostaddevops.click`

17. **Custom SSL certificate:**
    - Select the certificate you imported (shows domain name)
    - If not visible, verify:
      - Certificate is in us-east-1 region
      - Certificate status is "Issued"

18. **Security policy:** TLSv1.2_2021 (recommended)

19. **Standard logging:** Off (optional, enable to log requests)

20. **IPv6:** On (recommended)

21. **Default root object:** `index.html`

22. **Description:** `CloudFront distribution for batch10.ostaddevops.click`

### Custom Error Responses

23. Scroll down, click **Create custom error response**
24. **HTTP error code:** 404: Not Found
25. **Customize error response:** Yes
26. **Response page path:** `/error.html`
27. **HTTP Response code:** 404: Not Found
28. Click **Create custom error response**

### Create Distribution

29. Review all settings
30. Click **Create distribution**

**Wait Time:** 
- Status will show **Deploying** (takes 5-15 minutes)
- **Copy the Distribution domain name** (format: `d1234567890abc.cloudfront.net`)
- **Copy the Distribution ID** (format: `E1234567890ABC`)
- Both are shown at the top of the distribution details page

---

## Step 11: Update S3 Bucket Policy

After CloudFront distribution is created, you'll see a banner:

**"The S3 bucket policy needs to be updated"**

### Option A: Use the Banner (Easiest)

1. Click **Copy policy** in the blue banner
2. Click the **Go to S3 bucket permissions** link
3. In bucket **Permissions** tab, scroll to **Bucket policy**
4. Click **Edit**
5. Paste the copied policy
6. Click **Save changes**

### Option B: Manual Policy Creation

1. Go to your S3 bucket → **Permissions** tab
2. Scroll to **Bucket policy**
3. Click **Edit**
4. Paste this policy (replace values):

```json
{
    "Version": "2012-10-17",
    "Statement": {
        "Sid": "AllowCloudFrontServicePrincipal",
        "Effect": "Allow",
        "Principal": {
            "Service": "cloudfront.amazonaws.com"
        },
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::ostad-devops-batch-10/*",
        "Condition": {
            "StringEquals": {
                "AWS:SourceArn": "arn:aws:cloudfront::388779989543:distribution/YOUR_DISTRIBUTION_ID"
            }
        }
    }
}
```

5. Replace:
   - `ostad-devops-batch-10` with your bucket name
   - `388779989543` with your AWS account ID
   - `YOUR_DISTRIBUTION_ID` with your CloudFront distribution ID

6. Click **Save changes**

---

## Step 12: Wait for CloudFront Deployment

### Check Deployment Status

1. **CloudFront Console** → **Distributions**
2. Find your distribution
3. **Status** column should show:
   - **Deploying** → Wait (5-15 minutes)
   - **Enabled** → Ready to use!

### Test CloudFront URL

Once deployed, test the CloudFront domain:

```bash
# Replace with your CloudFront domain
curl -I https://d1234567890abc.cloudfront.net
```

You should see HTTP 200 and your index.html content.

---

## Step 13: Create Route53 DNS Records

### Navigate to Route53

1. **Open AWS Console** → Search for **"Route53"**
2. Click **Hosted zones** in left menu
3. Click on your hosted zone: `ostaddevops.click`

### Create A Record (IPv4)

4. Click **Create record**

5. **Record name:** `batch10` (will become batch10.ostaddevops.click)

6. **Record type:** A - Routes traffic to an IPv4 address and some AWS resources

7. **Alias:** Toggle **ON** (switch to Yes)

8. **Route traffic to:**
   - Choose: **Alias to CloudFront distribution**
   - Select your CloudFront distribution from dropdown
   - Or paste CloudFront domain: `d1234567890abc.cloudfront.net`

9. **Routing policy:** Simple routing

10. **Evaluate target health:** No

11. Click **Create records**

### Create AAAA Record (IPv6)

12. Click **Create record** again

13. **Record name:** `batch10`

14. **Record type:** AAAA - Routes traffic to an IPv6 address and some AWS resources

15. **Alias:** Toggle **ON**

16. **Route traffic to:**
   - Choose: **Alias to CloudFront distribution**
   - Select your CloudFront distribution
   - Same distribution as A record

17. Click **Create records**

### Verify Records

18. You should now see two records:
    - `batch10.ostaddevops.click` - Type A
    - `batch10.ostaddevops.click` - Type AAAA

---

# PHASE 3: Testing & Verification

## Step 14: Wait for DNS Propagation

DNS changes can take 5-60 minutes to propagate globally.

### Check DNS Resolution

From your Ubuntu server or local machine:

```bash
# Test DNS resolution
nslookup batch10.ostaddevops.click

# Detailed DNS query
dig batch10.ostaddevops.click

# Should show CloudFront IP addresses
```

---

## Step 15: Test Your Website

### Test HTTPS Access

```bash
# Test HTTPS (should work)
curl -I https://batch10.ostaddevops.click

# Expected: HTTP/2 200
```

### Test HTTP Redirect

```bash
# Test HTTP (should redirect to HTTPS)
curl -I http://batch10.ostaddevops.click

# Expected: HTTP/1.1 301 Moved Permanently
# Location: https://batch10.ostaddevops.click/
```

### Test Homepage

```bash
# Get full page content
curl https://batch10.ostaddevops.click
```

### Test Error Page

```bash
# Test 404 error page
curl https://batch10.ostaddevops.click/nonexistent

# Should show your error.html content
```

### Test SSL Certificate

```bash
# Verify SSL certificate
openssl s_client -connect batch10.ostaddevops.click:443 -servername batch10.ostaddevops.click

# Look for:
# - issuer: Let's Encrypt
# - Verification: OK
```

### Test in Browser

1. Open browser
2. Navigate to: `https://batch10.ostaddevops.click`
3. Click the **padlock icon** in address bar
4. Verify certificate details:
   - Issued by: R3 (Let's Encrypt)
   - Valid for 90 days
   - Domain matches

---

# PHASE 4: Maintenance

## Certificate Renewal (Every 60-80 Days)

Let's Encrypt certificates expire every **90 days**. Renew before expiration!

### Set Calendar Reminder

**Set a reminder for 60 days from today** to renew certificate.

### Renewal Process on Ubuntu

**60 days from now, run:**

```bash
# Test renewal (dry run - doesn't actually renew)
sudo certbot renew --dry-run

# Actual renewal (when ready)
sudo certbot renew --force-renewal

# Export renewed certificate
cd ~/ssl-certs
sudo cat /etc/letsencrypt/live/batch10.ostaddevops.click/cert.pem > cert.pem
sudo cat /etc/letsencrypt/live/batch10.ostaddevops.click/privkey.pem > privkey.pem
sudo cat /etc/letsencrypt/live/batch10.ostaddevops.click/chain.pem > chain.pem
```

### Re-import to ACM Console

1. **AWS Console** → **Certificate Manager** (in us-east-1)
2. Click on your existing certificate
3. Click **Actions** → **Reimport certificate**
4. Paste renewed certificate files:
   - Certificate body: `cat ~/ssl-certs/cert.pem`
   - Private key: `cat ~/ssl-certs/privkey.pem`
   - Certificate chain: `cat ~/ssl-certs/chain.pem`
5. Click **Review and import** → **Import**

**CloudFront will automatically use the renewed certificate** (same ARN).

---

## Update Website Content

### Upload New Files to S3

1. **AWS Console** → **S3** → Your bucket
2. Click **Upload**
3. Add files
4. Click **Upload**

### Invalidate CloudFront Cache

After uploading new files, CloudFront needs to refresh its cache:

1. **CloudFront Console** → **Distributions**
2. Click your distribution ID
3. Click **Invalidations** tab
4. Click **Create invalidation**
5. **Object paths:** Enter `/*` (invalidates all files)
6. Click **Create invalidation**

Wait 1-5 minutes for invalidation to complete.

---

## Monitoring

### CloudFront Metrics

1. **CloudFront Console** → Your distribution
2. Click **Monitoring** tab
3. View metrics:
   - Requests
   - Bytes downloaded
   - Error rates
   - Cache hit ratio

### S3 Metrics

1. **S3 Console** → Your bucket
2. Click **Metrics** tab
3. View storage and request metrics

### Set Up Billing Alerts

1. **AWS Console** → **Billing Dashboard**
2. Click **Billing preferences**
3. Enable: Receive billing alerts
4. Set up CloudWatch alarm for costs exceeding threshold

---

# 📊 Architecture Summary

Your complete setup:

```
┌─────────────────────────────────────────────────────────────┐
│                          INTERNET                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                      Route53 DNS                             │
│  batch10.ostaddevops.click                                 │
│  - A Record    → CloudFront (IPv4)                          │
│  - AAAA Record → CloudFront (IPv6)                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                   CloudFront Distribution                    │
│  - Global CDN (200+ edge locations)                         │
│  - HTTPS only (HTTP redirects to HTTPS)                     │
│  - SSL Certificate (Let's Encrypt via ACM us-east-1)        │
│  - Custom domain: batch10.ostaddevops.click                │
│  - Cache & Compression enabled                              │
│  - Custom error responses (404 → error.html)                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓ (via OAC)
┌─────────────────────────────────────────────────────────────┐
│                    S3 Bucket (PRIVATE)                       │
│  Name: ostad-devops-batch-10                                │
│  Region: ap-south-1 (Mumbai)                                │
│  - Block Public Access: ENABLED                             │
│  - Static Website Hosting: ENABLED                          │
│  - Accessible only via CloudFront OAC                       │
│  - Files: index.html, error.html                            │
└─────────────────────────────────────────────────────────────┘
```

---

# 🔒 Security Best Practices

✅ **S3 Bucket is Private**
- Block Public Access enabled
- No public bucket policy
- Accessible only via CloudFront OAC

✅ **HTTPS Enforced**
- HTTP automatically redirects to HTTPS
- TLS 1.2 minimum version
- Let's Encrypt trusted certificate

✅ **Origin Access Control**
- CloudFront uses OAC (newer, more secure than OAI)
- S3 bucket policy restricts access to specific CloudFront distribution

✅ **No Hardcoded Credentials**
- Uses IAM roles and temporary credentials
- Private key never leaves secure environment

---

# 💰 Cost Breakdown

### Free Tier (First 12 Months)
- **S3:** 5 GB storage, 20,000 GET requests, 2,000 PUT requests
- **CloudFront:** 1 TB data transfer out per month
- **Route53:** No free tier (but very low cost)

### Regular Pricing (Low Traffic Site)
- **S3 Storage:** ~$0.023/GB/month (ap-south-1)
- **S3 Requests:** $0.0004 per 1,000 GET requests
- **CloudFront:** $0.085/GB (after 1TB free)
- **Route53 Hosted Zone:** $0.50/month
- **ACM Certificate:** FREE (imported certificates)
- **Let's Encrypt:** FREE

**Estimated Monthly Cost:** < $5 for low-traffic sites

---

# 🔧 Troubleshooting

## Problem: Certificate import fails

**Solution:**
- Verify you're in **us-east-1** region
- Check certificate files have proper BEGIN/END markers
- Ensure no extra whitespace before/after certificate content
- Verify private key matches certificate

## Problem: CloudFront shows 403 Forbidden

**Solution:**
1. Check S3 bucket policy allows CloudFront
2. Verify OAC is attached to CloudFront
3. Ensure files exist in S3 bucket
4. Check default root object is `index.html`

## Problem: DNS not resolving

**Solution:**
1. Wait 5-60 minutes for DNS propagation
2. Verify Route53 records created correctly
3. Check domain is using Route53 nameservers
4. Test with: `dig batch10.ostaddevops.click`

## Problem: SSL certificate warning in browser

**Solution:**
1. Wait for CloudFront deployment to complete
2. Verify certificate ARN is correct in CloudFront
3. Check certificate is valid and not expired
4. Clear browser cache

## Problem: Old content showing after update

**Solution:**
1. Create CloudFront invalidation for `/*`
2. Wait 1-5 minutes for invalidation
3. Clear browser cache
4. Test with: `curl -I https://your-domain.com` (check Date header)

---

# 📚 AWS Console Navigation Quick Reference

| Service | Console Path |
|---------|-------------|
| **S3** | Services → Storage → S3 |
| **CloudFront** | Services → Networking & Content Delivery → CloudFront |
| **Route53** | Services → Networking & Content Delivery → Route 53 |
| **ACM** | Services → Security, Identity, & Compliance → Certificate Manager |
| **IAM** | Services → Security, Identity, & Compliance → IAM |
| **Systems Manager** | Services → Management & Governance → Systems Manager |

---

# ✅ Post-Setup Checklist

- [ ] SSL certificate imported to ACM (us-east-1)
- [ ] S3 bucket created and private
- [ ] Website files uploaded (index.html, error.html)
- [ ] CloudFront OAC created
- [ ] CloudFront distribution created and deployed
- [ ] S3 bucket policy updated for CloudFront OAC
- [ ] Route53 A record created
- [ ] Route53 AAAA record created
- [ ] Website accessible via HTTPS
- [ ] HTTP redirects to HTTPS
- [ ] SSL certificate valid in browser
- [ ] Error page works (test with /nonexistent)
- [ ] Calendar reminder set for certificate renewal (60 days)

---

# 📱 Quick Commands Reference Card

```bash
# Test website
curl -I https://batch10.ostaddevops.click

# Test SSL
openssl s_client -connect batch10.ostaddevops.click:443

# Test DNS
dig batch10.ostaddevops.click

# Renew certificate (Ubuntu)
sudo certbot renew --force-renewal

# View certificate expiry
openssl x509 -in ~/ssl-certs/cert.pem -noout -dates

# Upload to S3 (from AWS CLI)
aws s3 cp yourfile.html s3://ostad-devops-batch-10/ \
  --content-type "text/html; charset=utf-8"

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id YOUR_DIST_ID \
  --paths "/*"
```

---

# 🎓 What You've Learned

✅ How to request SSL certificates with Let's Encrypt and Certbot
✅ DNS-01 challenge validation using Route53
✅ Importing certificates to AWS Certificate Manager
✅ Creating private S3 buckets for static websites
✅ Setting up CloudFront distributions with custom domains
✅ Using Origin Access Control (OAC) for secure S3 access
✅ Configuring Route53 DNS records (A and AAAA)
✅ Implementing HTTPS-only with certificate pinning
✅ Certificate lifecycle management and renewal
✅ CloudFront cache invalidation strategies

---

# 📖 Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [AWS S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [AWS Certificate Manager User Guide](https://docs.aws.amazon.com/acm/)
- [Route53 Developer Guide](https://docs.aws.amazon.com/route53/)
- [Certbot Documentation](https://certbot.eff.org/docs/)

---

**🎉 Congratulations!** You've successfully set up a production-ready static website with global CDN, SSL certificate, and custom domain using AWS services!

---

**Ostad DevOps Batch-08 | Module 01 | Class 02**

For questions or support, refer to the automated scripts in the repository or contact your instructor.
