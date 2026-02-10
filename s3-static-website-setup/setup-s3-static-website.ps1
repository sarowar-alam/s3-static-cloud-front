# ============================================
# S3 Static Website Setup - PowerShell Script
# Creates a PUBLIC S3 bucket and enables 
# static website hosting for direct browsing
# ============================================

# Configuration Variables
$BUCKET_NAME = "ostad-devops-batch-2026"  # Change this to your desired bucket name
$AWS_REGION = "ap-south-1"                 # Change this to your preferred region
$AWS_PROFILE = "sarowar-ostad"                   # Change this to your AWS CLI profile name

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "         S3 Static Website Setup Script                    " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:"
Write-Host "  Bucket Name: $BUCKET_NAME" -ForegroundColor Yellow
Write-Host "  AWS Region:  $AWS_REGION" -ForegroundColor Yellow
Write-Host "  AWS Profile: $AWS_PROFILE" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Continue with this configuration? (y/n)"
if ($confirmation -notmatch "^[Yy]$") {
    Write-Host "Setup cancelled." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Step 1: Creating S3 Bucket" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

try {
    aws s3 mb "s3://$BUCKET_NAME" --region $AWS_REGION --profile $AWS_PROFILE 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Bucket '$BUCKET_NAME' created successfully" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Bucket may already exist or creation failed" -ForegroundColor Yellow
        Write-Host "Continuing with existing bucket..." -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARNING] Error creating bucket: $_" -ForegroundColor Yellow
    Write-Host "Continuing..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Step 2: Disabling Block Public Access" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

aws s3api put-public-access-block `
  --bucket $BUCKET_NAME `
  --profile $AWS_PROFILE `
  --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Block Public Access disabled" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to disable Block Public Access" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Step 3: Uploading Website Files" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Upload index.html
if (Test-Path "..\index.html") {
    aws s3 cp ..\index.html "s3://$BUCKET_NAME/index.html" `
      --content-type "text/html; charset=utf-8" `
      --profile $AWS_PROFILE
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Uploaded: index.html" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to upload index.html" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[ERROR] index.html not found in current directory" -ForegroundColor Red
    exit 1
}

# Upload error.html
if (Test-Path "..\error.html") {
    aws s3 cp ..\error.html "s3://$BUCKET_NAME/error.html" `
      --content-type "text/html; charset=utf-8" `
      --profile $AWS_PROFILE
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Uploaded: error.html" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Failed to upload error.html" -ForegroundColor Yellow
    }
} else {
    Write-Host "[WARNING] error.html not found (optional)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Step 4: Enabling Static Website Hosting" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

aws s3 website "s3://$BUCKET_NAME/" `
  --index-document index.html `
  --error-document error.html `
  --profile $AWS_PROFILE

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Static website hosting enabled" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to enable static website hosting" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Step 5: Creating Bucket Policy for Public Read Access" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Check if bucket-policy.json exists
if (-not (Test-Path "bucket-policy.json")) {
    Write-Host "[ERROR] bucket-policy.json not found in current directory" -ForegroundColor Red
    exit 1
}

# Read the policy template and replace placeholder with actual bucket name
$policyContent = Get-Content "bucket-policy.json" -Raw
$policyContent = $policyContent -replace 'BUCKET_NAME_PLACEHOLDER', $BUCKET_NAME

# Save modified policy to temporary file (using ASCII to avoid BOM issues)
$tempPolicyFile = Join-Path $env:TEMP "bucket-policy-temp.json"
[System.IO.File]::WriteAllText($tempPolicyFile, $policyContent)

# Convert Windows path to forward slashes for AWS CLI
$tempPolicyFileUnix = $tempPolicyFile -replace '\\', '/'

# Apply bucket policy
aws s3api put-bucket-policy `
  --bucket $BUCKET_NAME `
  --policy "file://$tempPolicyFileUnix" `
  --profile $AWS_PROFILE

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Public read bucket policy applied" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to apply bucket policy" -ForegroundColor Red
    Remove-Item $tempPolicyFile -ErrorAction SilentlyContinue
    exit 1
}

# Clean up temporary file
Remove-Item $tempPolicyFile -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "                  Setup Complete!                           " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your static website is now live and accessible at:" -ForegroundColor White
Write-Host ""
Write-Host "  URL: http://$BUCKET_NAME.s3-website.$AWS_REGION.amazonaws.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor Gray
Write-Host "Website Details:" -ForegroundColor White
Write-Host "  - Bucket Name:     $BUCKET_NAME" -ForegroundColor White
Write-Host "  - AWS Region:      $AWS_REGION" -ForegroundColor White
Write-Host "  - Index Document:  index.html" -ForegroundColor White
Write-Host "  - Error Document:  error.html" -ForegroundColor White
Write-Host "  - Access:          Public (HTTP only)" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor Gray
Write-Host ""
Write-Host "NOTES:" -ForegroundColor Yellow
Write-Host "  - Website is accessible via HTTP (not HTTPS)" -ForegroundColor White
Write-Host "  - For HTTPS and custom domain, use CloudFront" -ForegroundColor White
Write-Host "  - Bucket is publicly readable by anyone" -ForegroundColor White
Write-Host ""
Write-Host "To update your website:" -ForegroundColor Yellow
Write-Host "  aws s3 cp yourfile.html s3://$BUCKET_NAME/ ``" -ForegroundColor White
Write-Host "    --content-type `"text/html; charset=utf-8`" ``" -ForegroundColor White
Write-Host "    --profile $AWS_PROFILE" -ForegroundColor White
Write-Host ""
Write-Host "To delete the bucket and website:" -ForegroundColor Yellow
Write-Host "  aws s3 rb s3://$BUCKET_NAME --force --profile $AWS_PROFILE" -ForegroundColor White
Write-Host ""
