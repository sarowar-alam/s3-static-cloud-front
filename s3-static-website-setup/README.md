# S3 Static Website Setup Guide

This folder contains scripts to create a **public S3 bucket** configured for static website hosting with HTTP access.

## Files in This Folder

- **setup-s3-static-website.ps1** - PowerShell script for Windows
- **setup-s3-static-website.sh** - Bash script for Linux/Mac/WSL
- **bucket-policy.json** - S3 bucket policy template for public read access

---

## Method 1: Automated Setup (Using Scripts)

### Prerequisites

- AWS CLI installed and configured
- AWS credentials with appropriate permissions
- `index.html` and `error.html` files in the parent directory

### Option A: Windows (PowerShell)

1. **Open PowerShell** in this directory
   ```powershell
   cd s3-static-website-setup
   ```

2. **Edit configuration** (optional)  
   Open `setup-s3-static-website.ps1` and modify these variables:
   ```powershell
   $BUCKET_NAME = "ostad-devops-batch-2026"  # Your bucket name
   $AWS_REGION = "ap-south-1"                # Your AWS region
   $AWS_PROFILE = "sarowar-ostad"            # Your AWS profile
   ```

3. **Set execution policy** (if needed)
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

4. **Run the script**
   ```powershell
   .\setup-s3-static-website.ps1
   ```

5. **Confirm setup** when prompted and wait for completion

### Option B: Linux/Mac/WSL (Bash)

1. **Open terminal** in this directory
   ```bash
   cd s3-static-website-setup
   ```

2. **Edit configuration** (optional)  
   Open `setup-s3-static-website.sh` and modify these variables:
   ```bash
   BUCKET_NAME="ostad-devops-batch-2026"  # Your bucket name
   AWS_REGION="ap-south-1"                # Your AWS region
   AWS_PROFILE="sarowar-ostad"            # Your AWS profile
   ```

3. **Make script executable**
   ```bash
   chmod +x setup-s3-static-website.sh
   ```

4. **Run the script**
   ```bash
   ./setup-s3-static-website.sh
   ```

5. **Confirm setup** when prompted and wait for completion

### What the Script Does

The automated script performs these steps:
1. Creates S3 bucket in your specified region
2. Disables "Block Public Access" settings
3. Uploads `index.html` and `error.html` to the bucket
4. Enables static website hosting
5. Applies bucket policy for public read access
6. Displays the website URL

### Expected Output

```
============================================================
                  Setup Complete!
============================================================

Your static website is now live and accessible at:

  URL: http://your-bucket-name.s3-website.ap-south-1.amazonaws.com
```

---

## Method 2: Manual Setup (AWS Console)

Follow these detailed steps to set up your S3 static website using the AWS Management Console.

### Step 1: Sign in to AWS Console

1. Go to [https://console.aws.amazon.com/](https://console.aws.amazon.com/)
2. Sign in with your AWS account credentials
3. Make sure you're in your desired region (e.g., `ap-south-1` - Mumbai)

### Step 2: Create S3 Bucket

1. Navigate to **S3 service**:
   - Search for "S3" in the top search bar
   - Click on **S3** under Services

2. Click **Create bucket** button

3. Configure bucket settings:
   - **Bucket name**: Enter a globally unique name (e.g., `ostad-devops-batch-2026`)
   - **AWS Region**: Select your region (e.g., `Asia Pacific (Mumbai) ap-south-1`)
   - **Object Ownership**: Leave as default (ACLs disabled)

4. **Block Public Access settings**:
   - **UNCHECK** "Block all public access"
   - Check the acknowledgment box: "I acknowledge that the current settings might result in this bucket and the objects within becoming public"
   
5. **Bucket Versioning**: Leave disabled (optional for static sites)

6. **Tags**: Add tags if needed (optional)

7. **Default encryption**: Leave default settings

8. Click **Create bucket**

### Step 3: Upload Website Files

1. Click on your newly created bucket name

2. Click **Upload** button

3. Click **Add files**

4. Select your website files:
   - `index.html` (required)
   - `error.html` (optional but recommended)

5. In **Permissions** section:
   - Expand **Access control list (ACL)**
   - Nothing to change here for now

6. Click **Upload**

7. Wait for upload to complete, then click **Close**

### Step 4: Enable Static Website Hosting

1. In your bucket, go to the **Properties** tab

2. Scroll down to **Static website hosting** section

3. Click **Edit**

4. Configure static website hosting:
   - **Static website hosting**: Select **Enable**
   - **Hosting type**: Select **Host a static website**
   - **Index document**: Enter `index.html`
   - **Error document**: Enter `error.html`

5. Click **Save changes**

6. **Note the website endpoint** that appears (you'll use this to access your site):
   ```
   http://your-bucket-name.s3-website.ap-south-1.amazonaws.com
   ```

### Step 5: Set Bucket Policy for Public Read Access

1. Go to the **Permissions** tab of your bucket

2. Scroll down to **Bucket policy** section

3. Click **Edit**

4. Copy and paste this policy (replace `YOUR-BUCKET-NAME` with your actual bucket name):

   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "PublicReadGetObject",
         "Effect": "Allow",
         "Principal": "*",
         "Action": "s3:GetObject",
         "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
       }
     ]
   }
   ```

5. Click **Save changes**

### Step 6: Verify Your Website

1. Copy the **website endpoint** from Step 4

2. Open the URL in your web browser:
   ```
   http://your-bucket-name.s3-website.ap-south-1.amazonaws.com
   ```

3. You should see your `index.html` page displayed

4. Test the error page by accessing a non-existent page:
   ```
   http://your-bucket-name.s3-website.ap-south-1.amazonaws.com/nonexistent.html
   ```
   This should display your `error.html` page

---

## Important Notes

### Security Considerations

- **Public Access**: This setup makes your bucket publicly readable by anyone on the internet
- **HTTP Only**: Website is served over HTTP (not HTTPS). For HTTPS, use CloudFront
- **Read-Only**: The bucket policy only allows reading objects, not writing or deleting

### Website Access

- **Website URL Format**: 
  ```
  http://<bucket-name>.s3-website.<region>.amazonaws.com
  ```
- **Direct S3 URL** (won't work for website): 
  ```
  https://<bucket-name>.s3.<region>.amazonaws.com/<object-key>
  ```
  This URL works for individual files but doesn't support index document or error page features

### Updating Your Website

**Using AWS CLI:**
```bash
# Upload new/updated file
aws s3 cp newfile.html s3://your-bucket-name/ \
  --content-type "text/html; charset=utf-8" \
  --profile your-profile

# Sync entire directory
aws s3 sync ./website-folder s3://your-bucket-name/ \
  --profile your-profile
```

**Using AWS Console:**
1. Go to your S3 bucket
2. Click **Upload**
3. Add files (will overwrite existing files with same name)
4. Click **Upload**

### Cost Information

- **S3 Storage**: ~$0.023 per GB/month (ap-south-1)
- **Data Transfer**: First 1 GB free, then ~$0.109 per GB out to internet
- **Requests**: Very minimal cost for typical static websites
- **Free Tier**: 5 GB storage, 20,000 GET requests, 2,000 PUT requests per month (first 12 months)

### Common Issues & Solutions

**Issue**: "AccessDenied" when accessing website  
**Solution**: 
- Check if Block Public Access is disabled
- Verify bucket policy is applied correctly
- Ensure objects are uploaded successfully

**Issue**: "NoSuchBucket" error  
**Solution**: 
- Verify bucket name is correct
- Check you're accessing the correct region endpoint

**Issue**: Getting XML error page instead of custom error.html  
**Solution**: 
- Make sure `error.html` exists in bucket
- Verify static website hosting is enabled
- Check error document is set to `error.html`

**Issue**: Index document not showing (get XML listing instead)  
**Solution**: 
- Make sure you're using the website endpoint (not S3 endpoint)
- Use: `http://bucket.s3-website.region.amazonaws.com`
- Not: `https://bucket.s3.region.amazonaws.com`

---

## Cleanup (Delete Everything)

### Using AWS CLI

```bash
# Empty bucket
aws s3 rm s3://your-bucket-name --recursive --profile your-profile

# Delete bucket
aws s3 rb s3://your-bucket-name --profile your-profile
```

### Using AWS Console

1. Go to S3 service
2. Select your bucket (checkbox)
3. Click **Empty** button
4. Type "permanently delete" and click **Empty**
5. After bucket is empty, click **Delete** button
6. Type bucket name and click **Delete bucket**

---

## Additional Resources

- [AWS S3 Static Website Hosting Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [S3 Bucket Policy Examples](https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html)
- [AWS CLI S3 Commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)

---

## Next Steps

For production websites, consider:
- **CloudFront CDN**: For HTTPS, custom domain, and global distribution
- **Route 53**: For custom domain name management
- **AWS Certificate Manager**: For free SSL/TLS certificates
- **AWS WAF**: For web application firewall protection

See the `s3-cloudfront-setup` folder for CloudFront + S3 setup scripts.

---

## Author
*Md. Sarowar Alam*  
Lead DevOps Engineer, Hogarth Worldwide  
Email: sarowar@hotmail.com  
LinkedIn: [linkedin.com/in/sarowar](https://www.linkedin.com/in/sarowar/)

---
