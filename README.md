# AWS S3 Static Website Hosting - Complete Guide

This workspace contains **automated scripts and comprehensive guides** for deploying static websites on AWS using two different approaches:

1. **Public S3 Bucket** - Simple HTTP static website hosting
2. **Private S3 + CloudFront** - Secure HTTPS hosting with global CDN

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [When to Use Which Approach](#when-to-use-which-approach)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Features Comparison](#features-comparison)
- [Cost Comparison](#cost-comparison)
- [Additional Resources](#additional-resources)

---

## Overview

This project provides **complete automation and documentation** for deploying static websites on AWS S3 with optional CloudFront CDN integration. Whether you're learning AWS, building a portfolio site, or deploying a production website, these scripts and guides will help you get started quickly.

### What's Included

- **PowerShell scripts** for Windows
- **Bash scripts** for Linux/Mac/WSL
- **Detailed setup guides** with AWS Console instructions
- **Automated deployment** with configuration validation
- **Idempotent scripts** - safe to run multiple times
- **Cleanup instructions** for resource management
- **Troubleshooting guides** for common issues

---

## Project Structure

```
static-site/
|-- README.md                          # This file - main documentation
|-- index.html                         # Your website homepage
|-- error.html                         # Custom 404 error page
|
|-- s3-static-website-setup/           # Simple public S3 hosting
|   |-- README.md                      # Detailed guide for public S3
|   |-- setup-s3-static-website.ps1    # PowerShell automation script
|   |-- setup-s3-static-website.sh     # Bash automation script
|   `-- bucket-policy.json             # S3 bucket policy template
|
`-- s3-cloudfront-setup/               # Secure CloudFront + S3 hosting
    |-- README.md                      # Detailed guide for CloudFront
    |-- setup-cloudfront-website.ps1   # PowerShell automation script
    `-- setup-cloudfront-website.sh    # Bash automation script
```

---

## Quick Start

### Option 1: Public S3 (HTTP Only) - Simplest Setup

**Best for**: Learning, development, temporary demos

```powershell
# Windows
cd s3-static-website-setup
.\setup-s3-static-website.ps1
```

```bash
# Linux/Mac
cd s3-static-website-setup
chmod +x setup-s3-static-website.sh
./setup-s3-static-website.sh
```

**Result**: Website accessible at `http://your-bucket.s3-website.region.amazonaws.com`

 **[See detailed guide ](s3-static-website-setup/README.md)**

---

### Option 2: CloudFront + S3 (HTTPS) - Production Ready

**Best for**: Production websites, portfolios, business sites

```powershell
# Windows
cd s3-cloudfront-setup
.\setup-cloudfront-website.ps1
```

```bash
# Linux/Mac
cd s3-cloudfront-setup
chmod +x setup-cloudfront-website.sh
./setup-cloudfront-website.sh
```

**Result**: Website accessible at `https://d1234567890abc.cloudfront.net`

 **[See detailed guide ](s3-cloudfront-setup/README.md)**

---

## When to Use Which Approach

### Use **Public S3** When:

- Learning AWS S3 basics
- Building a development/test website
- Creating temporary demos or prototypes
- Cost is primary concern (lowest cost)
- HTTPS is not required
- Performance for one region is sufficient
- Simple setup is preferred

**Limitations**:
- HTTP only (no HTTPS)
- No CDN (slower for global users)
- No custom domain SSL support
- Bucket must be publicly readable

---

### Use **CloudFront + S3** When:

- Deploying production websites
- HTTPS/SSL is required
- Global audience (faster worldwide)
- Custom domain with SSL needed
- Private S3 bucket preferred (security)
- CDN caching benefits needed
- Professional portfolio or business site

**Benefits**:
- HTTPS with free AWS SSL certificate
- Global CDN (450+ edge locations)
- Private S3 bucket (more secure)
- Better performance worldwide
- Custom domain support
- DDoS protection included

---

## Prerequisites

### Required for Both Approaches

1. **AWS Account**
   - Sign up at [aws.amazon.com](https://aws.amazon.com)
   - Credit card required (free tier available)

2. **AWS CLI Installed**
   - Download: [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
   - Verify: `aws --version`

3. **AWS CLI Configured**
   ```bash
   aws configure --profile your-profile-name
   ```
   You'll need:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (e.g., `ap-south-1`)
   - Output format (e.g., `json`)

4. **Website Files**
   - `index.html` - Your homepage (required)
   - `error.html` - Custom 404 page (optional)

### Additional for Bash Scripts

5. **jq JSON Processor** (CloudFront script only)
   ```bash
   # Ubuntu/Debian
   sudo apt install jq
   
   # RHEL/CentOS
   sudo yum install jq
   
   # macOS
   brew install jq
   ```

### AWS IAM Permissions Required

Your AWS user/role needs these permissions:

**For Public S3:**
- `s3:CreateBucket`
- `s3:PutObject`
- `s3:PutBucketPolicy`
- `s3:PutBucketWebsite`
- `s3:PutPublicAccessBlock`

**For CloudFront + S3 (additional):**
- `cloudfront:CreateDistribution`
- `cloudfront:CreateOriginAccessControl`
- `cloudfront:GetDistribution`
- `cloudfront:ListDistributions`
- `sts:GetCallerIdentity`

---

## Getting Started

### Step 1: Prepare Your Website Files

1. Create or edit `index.html` in this directory
2. Create or edit `error.html` in this directory (optional)

**Example index.html:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My Static Website</title>
</head>
<body>
    <h1>Welcome to My Website!</h1>
    <p>This website is hosted on AWS S3.</p>
</body>
</html>
```

### Step 2: Configure AWS CLI

```bash
# Configure with named profile
aws configure --profile my-aws-profile

# Test configuration
aws s3 ls --profile my-aws-profile
```

### Step 3: Choose Your Approach

- **Learning/Development?**  Go to [s3-static-website-setup](s3-static-website-setup/)
- **Production/Portfolio?**  Go to [s3-cloudfront-setup](s3-cloudfront-setup/)

### Step 4: Edit Script Configuration

Open the script file and modify these variables:

```powershell
# PowerShell
$BUCKET_NAME = "your-unique-bucket-name"
$AWS_REGION = "ap-south-1"
$AWS_PROFILE = "your-profile-name"
```

```bash
# Bash
BUCKET_NAME="your-unique-bucket-name"
AWS_REGION="ap-south-1"
AWS_PROFILE="your-profile-name"
```

### Step 5: Run the Script

Follow the instructions in each folder's README.md file.

---

## Features Comparison

| Feature | Public S3 | CloudFront + S3 |
|---------|-----------|-----------------|
| **Setup Complexity** | Simple | Moderate |
| **Setup Time** | 1-2 minutes | 15-20 minutes* |
| **Protocol** | HTTP | HTTPS (+ HTTP redirect) |
| **Security** | Public bucket | Private bucket + OAC |
| **SSL/TLS** | Not available | Free AWS certificate |
| **Custom Domain** | Limited | Full support |
| **Global CDN** | Single region | 450+ edge locations |
| **Caching** | No CDN cache | Edge caching |
| **DDoS Protection** | Basic | AWS Shield Standard |
| **Access Control** | Public only | Private with OAC |
| **Cost** | Lowest | Higher (CDN costs) |
| **Best For** | Development, learning | Production, portfolios |

\* *Includes CloudFront deployment time*

---

## Cost Comparison

### Public S3 Hosting (ap-south-1 region)

**Monthly costs for a small website (100 MB, 10,000 visitors):**
- S3 Storage: 0.1 GB  $0.023 = **$0.002**
- S3 Requests: 10,000 GET  $0.004/10k = **$0.004**
- Data Transfer: 1 GB out  $0.109 = **$0.109**
- **Total**: ~**$0.12/month**

**Free Tier (first 12 months):**
- 5 GB storage
- 20,000 GET requests
- 2,000 PUT requests
- 1 GB data transfer out

---

### CloudFront + S3 Hosting (ap-south-1 region)

**Monthly costs for same website:**
- S3 Storage: 0.1 GB  $0.023 = **$0.002**
- CloudFront Data Transfer: 1 GB  $0.085 = **$0.085**
- CloudFront Requests: 10k  $0.0075/10k = **$0.0075**
- **Total**: ~**$0.10/month**

**Free Tier (first 12 months):**
- 1 TB CloudFront data transfer out
- 10 million HTTP/HTTPS requests
- 5 GB S3 storage

**Note**: CloudFront can be cheaper for high-traffic sites due to lower data transfer rates.

---

## Additional Resources

### AWS Documentation

- [Amazon S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Amazon CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/)
- [AWS Free Tier Details](https://aws.amazon.com/free/)

### Tutorials & Guides

- [Hosting a Static Website on S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront + S3 Tutorial](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/GettingStarted.SimpleDistribution.html)
- [Using Custom Domains with Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-cloudfront-distribution.html)

### AWS CLI Installation

- [Windows](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-windows.html)
- [macOS](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-mac.html)
- [Linux](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html)

---

## Customization & Extension

### Adding More Files

Both scripts upload `index.html` and `error.html` by default. To add more files:

**Manually via AWS CLI:**
```bash
aws s3 cp style.css s3://your-bucket/ \
  --content-type "text/css" \
  --profile your-profile
```

**Sync entire directory:**
```bash
aws s3 sync ./website-folder s3://your-bucket/ \
  --profile your-profile
```

### Adding Custom Domain

1. Register domain in Route 53 (or use existing domain)
2. Request SSL certificate in AWS Certificate Manager (us-east-1 for CloudFront)
3. Add CNAME to CloudFront distribution
4. Configure Route 53 to point to CloudFront

See [CloudFront README](s3-cloudfront-setup/README.md) for details.

---

## Troubleshooting

### Common Issues

**Script errors "bucket already exists"**
- Both scripts handle this gracefully and continue with existing bucket
- Scripts are idempotent - safe to run multiple times

**403 Forbidden errors**
- For Public S3: Check bucket policy and public access settings
- For CloudFront: Check OAC configuration and bucket policy

**Website not updating**
- For Public S3: Changes reflect immediately in S3
- For CloudFront: Create cache invalidation after updates

**AWS credentials errors**
- Run `aws configure --profile your-profile` to reconfigure
- Verify profile name matches script configuration

For detailed troubleshooting, see:
- [Public S3 Troubleshooting](s3-static-website-setup/README.md#common-issues--solutions)
- [CloudFront Troubleshooting](s3-cloudfront-setup/README.md#troubleshooting)

---

## Support & Community

- **AWS Support**: [AWS Support Center](https://console.aws.amazon.com/support/)
- **AWS Forums**: [AWS Discussion Forums](https://forums.aws.amazon.com/)
- **AWS re:Post**: [Community Q&A](https://repost.aws/)
- **Stack Overflow**: Tag questions with `amazon-s3` and `amazon-cloudfront`

---

## Learning Path

### Beginner (Start Here)
1. Read this README
2. Follow [Public S3 Setup](s3-static-website-setup/README.md)
3. Deploy a simple website
4. Understand S3 bucket policies

### Intermediate
1. Follow [CloudFront Setup](s3-cloudfront-setup/README.md)
2. Understand Origin Access Control
3. Learn about CDN caching
4. Practice cache invalidation

### Advanced
1. Add custom domain with Route 53
2. Set up SSL certificate with ACM
3. Configure Lambda@Edge functions
4. Implement CI/CD pipeline for deployments

---

## Updates & Maintenance

**Script Version**: 1.0  
**Last Updated**: February 2026  
**AWS CLI Version**: 2.x  
**Tested Regions**: ap-south-1 (Mumbai)

---

**Ready to deploy?** Choose your approach:
- [Simple Public S3](s3-static-website-setup/)
- [Secure CloudFront + S3](s3-cloudfront-setup/)

**Happy deploying!**

---

## Author
*Md. Sarowar Alam*  
Lead DevOps Engineer, Hogarth Worldwide  
Email: sarowar@hotmail.com  
LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)

---
