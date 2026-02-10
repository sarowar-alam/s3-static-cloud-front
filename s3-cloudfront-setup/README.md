# S3 + CloudFront Static Website Setup Guide

This folder contains scripts to create a **private S3 bucket** with **CloudFront CDN** configured for secure HTTPS static website hosting.

## Files in This Folder

- **setup-cloudfront-website.ps1** - PowerShell script for Windows
- **setup-cloudfront-website.sh** - Bash script for Linux/Mac/WSL

---

## Method 1: Automated Setup (Using Scripts)

### Prerequisites

- AWS CLI installed and configured
- AWS credentials with appropriate permissions (S3, CloudFront, IAM)
- `index.html` and `error.html` files in the parent directory
- **For Bash script**: `jq` JSON processor installed

### Option A: Windows (PowerShell)

1. **Open PowerShell** in this directory
   ```powershell
   cd s3-cloudfront-setup
   ```

2. **Edit configuration** (optional)  
   Open `setup-cloudfront-website.ps1` and modify these variables:
   ```powershell
   $BUCKET_NAME = "ostad-devops-batch-2026-cf"  # Your bucket name
   $AWS_REGION = "ap-south-1"                    # Your AWS region
   $AWS_PROFILE = "sarowar-ostad"                # Your AWS profile
   ```

3. **Set execution policy** (if needed)
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

4. **Run the script**
   ```powershell
   .\setup-cloudfront-website.ps1
   ```

5. **Confirm setup** when prompted and wait for completion

### Option B: Linux/Mac/WSL (Bash)

1. **Install jq** (if not already installed)
   ```bash
   # Ubuntu/Debian
   sudo apt install jq
   
   # RHEL/CentOS/Fedora
   sudo yum install jq
   
   # macOS
   brew install jq
   ```

2. **Open terminal** in this directory
   ```bash
   cd s3-cloudfront-setup
   ```

3. **Edit configuration** (optional)  
   Open `setup-cloudfront-website.sh` and modify these variables:
   ```bash
   BUCKET_NAME="ostad-devops-batch-2026-cf"  # Your bucket name
   AWS_REGION="ap-south-1"                    # Your AWS region
   AWS_PROFILE="sarowar-ostad"                # Your AWS profile
   ```

4. **Make script executable**
   ```bash
   chmod +x setup-cloudfront-website.sh
   ```

5. **Run the script**
   ```bash
   ./setup-cloudfront-website.sh
   ```

6. **Confirm setup** when prompted and wait for completion

### What the Script Does

The automated script performs these steps:
1. Creates private S3 bucket (public access blocked)
2. Uploads `index.html` and `error.html` to the bucket
3. Creates Origin Access Control (OAC) for secure CloudFront-to-S3 access
4. Creates CloudFront distribution with HTTPS enabled
5. Configures custom error pages (404  error.html)
6. Applies S3 bucket policy allowing only CloudFront access
7. Displays the CloudFront HTTPS URL

### Expected Output

```

                   Setup Complete!                        


Your static website is now accessible via CloudFront:

   HTTPS URL: https://d1234567890abc.cloudfront.net

Configuration Details:
- S3 Bucket:           your-bucket-name (private)
- CloudFront Dist ID:  E1234567890ABC
- Protocol:            HTTPS (with redirect from HTTP)
```

**Note**: CloudFront distribution takes 5-15 minutes to deploy globally after creation.

---

## Method 2: Manual Setup (AWS Console)

Follow these detailed steps to set up CloudFront + S3 using the AWS Management Console.

### Step 1: Sign in to AWS Console

1. Go to [https://console.aws.amazon.com/](https://console.aws.amazon.com/)
2. Sign in with your AWS account credentials
3. Make sure you're in your desired region (e.g., `ap-south-1` - Mumbai)

### Step 2: Create Private S3 Bucket

1. Navigate to **S3 service**:
   - Search for "S3" in the top search bar
   - Click on **S3** under Services

2. Click **Create bucket** button

3. Configure bucket settings:
   - **Bucket name**: Enter a globally unique name (e.g., `my-cloudfront-bucket-2026`)
   - **AWS Region**: Select your region (e.g., `Asia Pacific (Mumbai) ap-south-1`)
   - **Object Ownership**: Leave as default (ACLs disabled)

4. **Block Public Access settings**:
   - **KEEP CHECKED** "Block all public access"
   - This is secure - CloudFront will access bucket privately

5. **Bucket Versioning**: Leave disabled (optional)

6. **Default encryption**: Leave default or enable if desired

7. Click **Create bucket**

### Step 3: Upload Website Files

1. Click on your newly created bucket name

2. Click **Upload** button

3. Click **Add files**

4. Select your website files:
   - `index.html` (required)
   - `error.html` (optional but recommended)

5. Click **Upload**

6. Wait for upload to complete, then click **Close**

### Step 4: Create Origin Access Control (OAC)

1. Navigate to **CloudFront** service (search "CloudFront" in top bar)

2. In the left sidebar, click **Origin access** under **Security**

3. Click **Create control setting**

4. Configure OAC:
   - **Name**: Enter a name (e.g., `my-bucket-oac`)
   - **Description**: Optional description
   - **Signing behavior**: Select **Sign requests (recommended)**
   - **Origin type**: Select **S3**

5. Click **Create**

6. **Copy the OAC ID** - you'll need this later

### Step 5: Create CloudFront Distribution

1. In CloudFront console, click **Distributions** in left sidebar

2. Click **Create distribution**

3. **Origin settings**:
   - **Origin domain**: Select your S3 bucket from dropdown
   - **Origin path**: Leave empty
   - **Name**: Auto-filled, you can customize
   - **Origin access**: Select **Origin access control settings (recommended)**
   - **Origin access control**: Select the OAC you created in Step 4
   - A warning appears: "The S3 bucket policy needs to be updated" - **Note this**, we'll do it in Step 6

4. **Default cache behavior settings**:
   - **Viewer protocol policy**: Select **Redirect HTTP to HTTPS**
   - **Allowed HTTP methods**: Select **GET, HEAD** (default)
   - **Cache policy**: Select **CachingOptimized** (recommended)
   - Leave other settings as default

5. **Settings**:
   - **Price class**: Select based on your needs (e.g., **Use all edge locations** for best performance)
   - **Alternate domain name (CNAME)**: Leave empty (unless you have a custom domain)
   - **Custom SSL certificate**: Leave as default (CloudFront provides free certificate)
   - **Default root object**: Enter `index.html`

6. **Custom error pages** (optional but recommended):
   - Skip for now, we'll add it after distribution is created

7. Click **Create distribution**

8. **Copy the Distribution ID and Domain Name** from the distribution details

### Step 6: Update S3 Bucket Policy

1. Go back to **S3 console**

2. Click on your bucket name

3. Go to **Permissions** tab

4. Scroll to **Bucket policy** section

5. Click **Edit**

6. **Get your AWS Account ID**:
   - Click your account name in top right
   - Copy the 12-digit Account ID

7. **Get your CloudFront Distribution ID**:
   - From Step 5, or go to CloudFront console and copy it

8. **Paste this bucket policy** (replace placeholders):

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "AllowCloudFrontServicePrincipal",
         "Effect": "Allow",
         "Principal": {
           "Service": "cloudfront.amazonaws.com"
         },
         "Action": "s3:GetObject",
         "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*",
         "Condition": {
           "StringEquals": {
             "AWS:SourceArn": "arn:aws:cloudfront::YOUR-ACCOUNT-ID:distribution/YOUR-DISTRIBUTION-ID"
           }
         }
       }
     ]
   }
   ```

   **Replace**:
   - `YOUR-BUCKET-NAME` with your actual bucket name
   - `YOUR-ACCOUNT-ID` with your 12-digit AWS account ID
   - `YOUR-DISTRIBUTION-ID` with your CloudFront distribution ID (starts with E...)

9. Click **Save changes**

### Step 7: Configure Custom Error Page (Optional)

1. Go to **CloudFront console**

2. Click on your distribution ID

3. Go to **Error pages** tab

4. Click **Create custom error response**

5. Configure error response:
   - **HTTP error code**: Select **404: Not Found**
   - **Customize error response**: Select **Yes**
   - **Response page path**: Enter `/error.html`
   - **HTTP Response code**: Select **404: Not Found**
   - **Error caching minimum TTL**: Enter `300` (5 minutes)

6. Click **Create custom error response**

### Step 8: Wait for Deployment

1. Go to CloudFront **Distributions** page

2. Your distribution **Status** will show "Deploying"

3. Wait 5-15 minutes for status to change to "Deployed"

4. You can refresh the page to check progress

### Step 9: Test Your Website

1. Copy the **Distribution domain name** (e.g., `d1234567890abc.cloudfront.net`)

2. Open in browser with HTTPS:
   ```
   https://d1234567890abc.cloudfront.net
   ```

3. You should see your `index.html` page

4. Test error page:
   ```
   https://d1234567890abc.cloudfront.net/nonexistent.html
   ```
   Should show your `error.html`

5. Test HTTP redirect - try with `http://` (should redirect to `https://`)

---

## Important Notes

### Security & Access

- **Private S3 Bucket**: Bucket is not publicly accessible
- **HTTPS Only**: All traffic encrypted with TLS/SSL
- **Origin Access Control**: Modern, secure method for CloudFront to access S3
- **No Direct S3 Access**: Files can only be accessed via CloudFront

### CloudFront Features

- **Global CDN**: Content cached at 450+ edge locations worldwide
- **Fast Performance**: Low latency, high transfer speeds
- **HTTPS Included**: Free AWS-managed SSL certificate
- **HTTP/2 & HTTP/3**: Automatic protocol optimization
- **Compression**: Automatic gzip/brotli compression

### Comparison with Public S3 Hosting

| Feature | Public S3 | S3 + CloudFront |
|---------|-----------|-----------------|
| **Protocol** | HTTP only | HTTPS (with HTTP redirect) |
| **Security** | Public bucket | Private bucket + OAC |
| **Performance** | Single region | Global CDN (450+ locations) |
| **Custom Domain** | Limited | Full support with Route53 |
| **SSL Certificate** | Not available | Free AWS certificate |
| **Cost** | Lower | Higher (CDN costs) |
| **Caching** | No CDN cache | Global edge caching |

---

## Updating Your Website

### Step 1: Upload New Files to S3

**Using AWS CLI:**
```bash
aws s3 cp newfile.html s3://your-bucket-name/ \
  --content-type "text/html; charset=utf-8" \
  --profile your-profile

# Or sync entire directory
aws s3 sync ./website-folder s3://your-bucket-name/ \
  --profile your-profile
```

**Using AWS Console:**
1. Go to your S3 bucket
2. Click **Upload**
3. Add files (will overwrite existing files with same name)
4. Click **Upload**

### Step 2: Invalidate CloudFront Cache

After uploading new files, you **must** invalidate CloudFront cache for changes to appear immediately.

**Using AWS CLI:**
```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR-DISTRIBUTION-ID \
  --paths "/*" \
  --profile your-profile
```

**Using AWS Console:**
1. Go to CloudFront console
2. Click on your distribution
3. Go to **Invalidations** tab
4. Click **Create invalidation**
5. Enter paths to invalidate:
   - For all files: `/*`
   - For specific file: `/index.html`
   - For folder: `/images/*`
6. Click **Create invalidation**

**Note**: 
- First 1,000 invalidation paths per month are free
- Additional paths cost $0.005 per path
- Cache invalidation takes 5-30 seconds to propagate

---

## Cost Information

### CloudFront Pricing (as of 2026, ap-south-1 region)

**Data Transfer Out**:
- First 10 TB/month: ~$0.085 per GB
- Next 40 TB/month: ~$0.080 per GB
- Over 150 TB/month: ~$0.060 per GB

**HTTP/HTTPS Requests**:
- Per 10,000 requests: ~$0.0075

**Invalidations**:
- First 1,000 paths/month: Free
- Additional paths: $0.005 per path

**S3 Storage** (ap-south-1):
- Standard: ~$0.023 per GB/month
- Minimal cost for static websites

### Free Tier (First 12 months)

- **CloudFront**: 1 TB data transfer out, 10,000,000 HTTP/HTTPS requests
- **S3**: 5 GB storage, 20,000 GET requests, 2,000 PUT requests

### Example Cost Estimate

**Small website** (100 MB content, 100,000 visitors/month, 10 pages each):
- S3 Storage: $0.10 GB  $0.023 = $0.002/month
- CloudFront Data Transfer: 100 GB  $0.085 = $8.50/month
- CloudFront Requests: 1M requests  $0.0075/10k = $0.75/month
- **Total**: ~$9.25/month (if not in free tier)

**Note**: Costs vary based on traffic and edge location usage.

---

## Troubleshooting

### Issue: "403 Forbidden" when accessing CloudFront URL

**Causes & Solutions**:

1. **Bucket policy not updated**:
   - Verify S3 bucket policy includes CloudFront service principal
   - Check Distribution ARN matches exactly in policy
   - Go to S3  Bucket  Permissions  Bucket Policy

2. **OAC not configured correctly**:
   - Go to CloudFront distribution  Origins tab
   - Verify OAC is attached to origin
   - Re-create OAC if necessary

3. **Objects not uploaded**:
   - Check S3 bucket contains index.html
   - Verify file names match exactly

### Issue: CloudFront shows old content after updating S3

**Solution**:
- Create cache invalidation (see "Updating Your Website" section)
- Wait 5-30 seconds for invalidation to complete
- Clear browser cache (Ctrl+F5) if still showing old content

### Issue: Distribution stuck in "Deploying" status

**Solution**:
- Wait at least 15-20 minutes
- If still deploying after 30 minutes, contact AWS support
- Check AWS Service Health Dashboard for CloudFront issues

### Issue: Index document not working (getting 404)

**Solution**:
- Verify **Default root object** is set to `index.html` in distribution settings
- Check index.html exists in S3 bucket root (not in subfolder)
- File name is case-sensitive: `index.html` not `Index.html`

### Issue: HTTP not redirecting to HTTPS

**Solution**:
- Go to CloudFront distribution  Behaviors tab
- Edit default behavior
- Set **Viewer protocol policy** to "Redirect HTTP to HTTPS"
- Save and wait for distribution to deploy

### Issue: Custom error page not showing

**Solution**:
- Verify error.html exists in S3 bucket
- Go to CloudFront  Error pages tab
- Add custom error response for 404 status code
- Set response page path to `/error.html`

---

## Cleanup (Delete Everything)

**Warning**: This will permanently delete all resources. Make sure you have backups if needed.

### Using Automated Commands

The setup script displays cleanup commands at the end. Copy and execute them in order:

### Manual Cleanup - Step by Step

#### 1. Disable CloudFront Distribution

**Using AWS CLI:**
```bash
# Get distribution config
CONFIG=$(aws cloudfront get-distribution-config \
  --id YOUR-DISTRIBUTION-ID \
  --profile your-profile)

# Extract ETag
ETAG=$(echo $CONFIG | jq -r '.ETag')

# Disable distribution
echo $CONFIG | jq '.DistributionConfig | .Enabled = false' > dist.json

aws cloudfront update-distribution \
  --id YOUR-DISTRIBUTION-ID \
  --if-match $ETAG \
  --distribution-config file://dist.json \
  --profile your-profile
```

**Using AWS Console:**
1. Go to CloudFront console
2. Select your distribution (checkbox)
3. Click **Disable**
4. Confirm and wait for deployment

#### 2. Wait for Distribution to Deploy

Check status:
```bash
aws cloudfront get-distribution \
  --id YOUR-DISTRIBUTION-ID \
  --query 'Distribution.Status' \
  --profile your-profile
```

Wait until status shows **"Deployed"** (5-10 minutes)

#### 3. Delete CloudFront Distribution

**Using AWS CLI:**
```bash
# Get fresh ETag
ETAG=$(aws cloudfront get-distribution \
  --id YOUR-DISTRIBUTION-ID \
  --profile your-profile | jq -r '.ETag')

# Delete distribution
aws cloudfront delete-distribution \
  --id YOUR-DISTRIBUTION-ID \
  --if-match $ETAG \
  --profile your-profile
```

**Using AWS Console:**
1. Select the disabled distribution
2. Click **Delete**
3. Confirm deletion

#### 4. Delete Origin Access Control

**Using AWS CLI:**
```bash
# Get OAC ETag
OAC_ETAG=$(aws cloudfront get-origin-access-control \
  --id YOUR-OAC-ID \
  --profile your-profile | jq -r '.ETag')

# Delete OAC
aws cloudfront delete-origin-access-control \
  --id YOUR-OAC-ID \
  --if-match $OAC_ETAG \
  --profile your-profile
```

**Using AWS Console:**
1. Go to CloudFront  Origin access (under Security)
2. Select your OAC
3. Click **Delete**

#### 5. Empty and Delete S3 Bucket

**Using AWS CLI:**
```bash
# Empty bucket
aws s3 rm s3://your-bucket-name --recursive --profile your-profile

# Delete bucket
aws s3 rb s3://your-bucket-name --profile your-profile
```

**Using AWS Console:**
1. Go to S3 console
2. Select your bucket
3. Click **Empty**  confirm
4. After empty, click **Delete**  type bucket name  confirm

---

## Additional Resources

- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [CloudFront + S3 Best Practices](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web-awsdns.html)
- [Origin Access Control (OAC) Guide](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)
- [Route 53 + CloudFront (Custom Domains)](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-cloudfront-distribution.html)
- [AWS Certificate Manager (Free SSL)](https://docs.aws.amazon.com/acm/)

---

## Next Steps

For production websites, consider:

- **Custom Domain**: Use Route 53 to configure your domain name
- **SSL Certificate**: Request free certificate from AWS Certificate Manager
- **Web Application Firewall (WAF)**: Add security rules to protect against attacks
- **Lambda@Edge**: Add serverless functions to modify requests/responses
- **CloudFront Functions**: Lightweight functions for URL rewrites, headers
- **Access Logs**: Enable CloudFront and S3 access logs for analytics
- **CloudWatch Monitoring**: Set up alarms for monitoring traffic and errors

---

## Support

For AWS-specific issues:
- [AWS Support Center](https://console.aws.amazon.com/support/)
- [AWS re:Post Community](https://repost.aws/)
- [AWS CloudFront Forum](https://forums.aws.amazon.com/forum.jspa?forumID=46)

---

**Related Folders:**
- See `s3-static-website-setup` folder for simple public S3 hosting (HTTP only, no CDN)

---

## Author
*Md. Sarowar Alam*  
Lead DevOps Engineer, Hogarth Worldwide  
Email: sarowar@hotmail.com  
LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)

---
