# ============================================
# S3 + CloudFront Static Website Setup
# Creates a PRIVATE S3 bucket with CloudFront
# distribution for secure HTTPS delivery
# ============================================

# Configuration Variables
$BUCKET_NAME = "ostad-devops-batch-2026-cf"  # Change this to your desired bucket name
$AWS_REGION = "ap-south-1"                    # Change this to your preferred region
$AWS_PROFILE = "sarowar-ostad"                # Change this to your AWS CLI profile name
$OAC_NAME = "$BUCKET_NAME-oac"                # Origin Access Control name

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "    S3 + CloudFront Static Website Setup Script            " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:"
Write-Host "  Bucket Name:  $BUCKET_NAME" -ForegroundColor Yellow
Write-Host "  AWS Region:   $AWS_REGION" -ForegroundColor Yellow
Write-Host "  AWS Profile:  $AWS_PROFILE" -ForegroundColor Yellow
Write-Host "  OAC Name:     $OAC_NAME" -ForegroundColor Yellow
Write-Host ""
Write-Host "This setup will:" -ForegroundColor White
Write-Host "  - Create a PRIVATE S3 bucket (public access blocked)" -ForegroundColor White
Write-Host "  - Upload your website files" -ForegroundColor White
Write-Host "  - Create CloudFront distribution with HTTPS" -ForegroundColor White
Write-Host "  - Configure Origin Access Control for security" -ForegroundColor White
Write-Host ""

$confirmation = Read-Host "Continue with this configuration? (y/n)"
if ($confirmation -notmatch "^[Yy]$") {
    Write-Host "Setup cancelled." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Step 1: Creating Private S3 Bucket" -ForegroundColor Cyan
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
Write-Host "Step 2: Verifying Public Access is Blocked (Security)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

aws s3api put-public-access-block `
  --bucket $BUCKET_NAME `
  --profile $AWS_PROFILE `
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Public access blocked (bucket is private)" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to configure block public access" -ForegroundColor Red
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
    Write-Host "[ERROR] index.html not found in parent directory" -ForegroundColor Red
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
Write-Host "Step 4: Creating Origin Access Control (OAC)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Check if OAC already exists
$oacList = aws cloudfront list-origin-access-controls --profile $AWS_PROFILE 2>&1 | ConvertFrom-Json
$existingOac = $null
$oacId = $null

if ($LASTEXITCODE -eq 0) {
    foreach ($item in $oacList.OriginAccessControlList.Items) {
        if ($item.Name -eq $OAC_NAME) {
            $existingOac = $item
            $oacId = $item.Id
            break
        }
    }
}

if ($null -ne $oacId) {
    Write-Host "[SUCCESS] Using existing Origin Access Control" -ForegroundColor Green
    Write-Host "          OAC ID: $oacId" -ForegroundColor Gray
} else {
    # Create OAC configuration
    $oacConfig = @{
        Name = $OAC_NAME
        Description = "OAC for $BUCKET_NAME"
        SigningProtocol = "sigv4"
        SigningBehavior = "always"
        OriginAccessControlOriginType = "s3"
    } | ConvertTo-Json -Compress

    $tempOacFile = Join-Path $env:TEMP "oac-config.json"
    [System.IO.File]::WriteAllText($tempOacFile, $oacConfig)

    # Create OAC
    $oacOutput = aws cloudfront create-origin-access-control `
      --origin-access-control-config "file://$($tempOacFile -replace '\\', '/')" `
      --profile $AWS_PROFILE 2>&1

    Remove-Item $tempOacFile -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -eq 0) {
        $oacId = ($oacOutput | ConvertFrom-Json).OriginAccessControl.Id
        Write-Host "[SUCCESS] Origin Access Control created" -ForegroundColor Green
        Write-Host "          OAC ID: $oacId" -ForegroundColor Gray
    } else {
        Write-Host "[ERROR] Failed to create Origin Access Control" -ForegroundColor Red
        Write-Host $oacOutput -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Step 5: Creating CloudFront Distribution" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Check if distribution already exists for this bucket
$distributions = aws cloudfront list-distributions --profile $AWS_PROFILE 2>&1 | ConvertFrom-Json
$existingDistribution = $null
$distributionId = $null
$domainName = $null

if ($LASTEXITCODE -eq 0) {
    foreach ($item in $distributions.DistributionList.Items) {
        if ($item.Origins.Items[0].DomainName -like "*$BUCKET_NAME*") {
            $existingDistribution = $item
            $distributionId = $item.Id
            $domainName = $item.DomainName
            break
        }
    }
}

if ($null -ne $distributionId) {
    Write-Host "[SUCCESS] Using existing CloudFront distribution" -ForegroundColor Green
    Write-Host "          Distribution ID: $distributionId" -ForegroundColor Gray
    Write-Host "          Domain Name: $domainName" -ForegroundColor Gray
} else {
    # Create CloudFront distribution configuration
    $callerReference = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
    $originDomain = "$BUCKET_NAME.s3.$AWS_REGION.amazonaws.com"

    $distributionConfig = @{
        CallerReference = $callerReference
        Comment = "CloudFront distribution for $BUCKET_NAME"
        Enabled = $true
        DefaultRootObject = "index.html"
        Origins = @{
            Quantity = 1
            Items = @(
                @{
                    Id = "S3-$BUCKET_NAME"
                    DomainName = $originDomain
                    S3OriginConfig = @{
                        OriginAccessIdentity = ""
                    }
                    OriginAccessControlId = $oacId
                }
            )
        }
        DefaultCacheBehavior = @{
            TargetOriginId = "S3-$BUCKET_NAME"
            ViewerProtocolPolicy = "redirect-to-https"
            AllowedMethods = @{
                Quantity = 2
                Items = @("GET", "HEAD")
                CachedMethods = @{
                    Quantity = 2
                    Items = @("GET", "HEAD")
                }
            }
            ForwardedValues = @{
                QueryString = $false
                Cookies = @{
                    Forward = "none"
                }
            }
            MinTTL = 0
            DefaultTTL = 86400
            MaxTTL = 31536000
            Compress = $true
            TrustedSigners = @{
                Enabled = $false
                Quantity = 0
            }
        }
        CustomErrorResponses = @{
            Quantity = 1
            Items = @(
                @{
                    ErrorCode = 404
                    ResponsePagePath = "/error.html"
                    ResponseCode = "404"
                    ErrorCachingMinTTL = 300
                }
            )
        }
    } | ConvertTo-Json -Depth 10 -Compress

    $tempDistFile = Join-Path $env:TEMP "cf-distribution.json"
    [System.IO.File]::WriteAllText($tempDistFile, $distributionConfig)

    Write-Host "Creating CloudFront distribution (this may take a few minutes)..." -ForegroundColor Yellow

    $cfOutput = aws cloudfront create-distribution `
      --distribution-config "file://$($tempDistFile -replace '\\', '/')" `
      --profile $AWS_PROFILE 2>&1

    Remove-Item $tempDistFile -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -eq 0) {
        $distribution = $cfOutput | ConvertFrom-Json
        $distributionId = $distribution.Distribution.Id
        $domainName = $distribution.Distribution.DomainName
        Write-Host "[SUCCESS] CloudFront distribution created" -ForegroundColor Green
        Write-Host "          Distribution ID: $distributionId" -ForegroundColor Gray
        Write-Host "          Domain Name: $domainName" -ForegroundColor Gray
    } else {
        Write-Host "[ERROR] Failed to create CloudFront distribution" -ForegroundColor Red
        Write-Host $cfOutput -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Step 6: Updating S3 Bucket Policy for CloudFront Access" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Get AWS account ID
$accountId = aws sts get-caller-identity --profile $AWS_PROFILE --query Account --output text 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to get AWS account ID" -ForegroundColor Red
    exit 1
}

# Create bucket policy for CloudFront OAC
$bucketPolicy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Sid = "AllowCloudFrontServicePrincipal"
            Effect = "Allow"
            Principal = @{
                Service = "cloudfront.amazonaws.com"
            }
            Action = "s3:GetObject"
            Resource = "arn:aws:s3:::$BUCKET_NAME/*"
            Condition = @{
                StringEquals = @{
                    "AWS:SourceArn" = "arn:aws:cloudfront::$accountId:distribution/$distributionId"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

$tempPolicyFile = Join-Path $env:TEMP "cf-bucket-policy.json"
[System.IO.File]::WriteAllText($tempPolicyFile, $bucketPolicy)

aws s3api put-bucket-policy `
  --bucket $BUCKET_NAME `
  --policy "file://$($tempPolicyFile -replace '\\', '/')" `
  --profile $AWS_PROFILE 2>&1 | Out-Null

Remove-Item $tempPolicyFile -ErrorAction SilentlyContinue

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Bucket policy applied for CloudFront access" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to apply bucket policy" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "                  Setup Complete!                           " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Your static website is now accessible via CloudFront:" -ForegroundColor White
Write-Host ""
Write-Host "  HTTPS URL: https://$domainName" -ForegroundColor Cyan
Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor Gray
Write-Host "Configuration Details:" -ForegroundColor White
Write-Host "  - S3 Bucket:           $BUCKET_NAME (private)" -ForegroundColor White
Write-Host "  - AWS Region:          $AWS_REGION" -ForegroundColor White
Write-Host "  - CloudFront Dist ID:  $distributionId" -ForegroundColor White
Write-Host "  - CloudFront Domain:   $domainName" -ForegroundColor White
Write-Host "  - Origin Access:       OAC (Origin Access Control)" -ForegroundColor White
Write-Host "  - Protocol:            HTTPS (with redirect from HTTP)" -ForegroundColor White
Write-Host "  - Index Document:      index.html" -ForegroundColor White
Write-Host "  - Error Document:      error.html" -ForegroundColor White
Write-Host "------------------------------------------------------------" -ForegroundColor Gray
Write-Host ""
Write-Host "IMPORTANT NOTES:" -ForegroundColor Yellow
Write-Host "  - CloudFront distribution is deploying (takes 5-15 minutes)" -ForegroundColor White
Write-Host "  - S3 bucket is PRIVATE - only accessible via CloudFront" -ForegroundColor White
Write-Host "  - All traffic is served over HTTPS" -ForegroundColor White
Write-Host "  - Content is cached globally for better performance" -ForegroundColor White
Write-Host ""
Write-Host "To update your website:" -ForegroundColor Yellow
Write-Host "  1. Upload new files to S3:" -ForegroundColor White
Write-Host "     aws s3 cp yourfile.html s3://$BUCKET_NAME/ --content-type `"text/html; charset=utf-8`" --profile $AWS_PROFILE" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Invalidate CloudFront cache:" -ForegroundColor White
Write-Host "     aws cloudfront create-invalidation --distribution-id $distributionId --paths `"/*`" --profile $AWS_PROFILE" -ForegroundColor Gray
Write-Host ""
Write-Host "To check distribution status:" -ForegroundColor Yellow
Write-Host "  aws cloudfront get-distribution --id $distributionId --profile $AWS_PROFILE --query 'Distribution.Status'" -ForegroundColor Gray
Write-Host ""
Write-Host "To delete everything (cleanup):" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Disable CloudFront distribution:" -ForegroundColor White
Write-Host "     `$config = aws cloudfront get-distribution-config --id $distributionId --profile $AWS_PROFILE | ConvertFrom-Json" -ForegroundColor Gray
Write-Host "     `$config.DistributionConfig.Enabled = `$false" -ForegroundColor Gray
Write-Host "     `$config.DistributionConfig | ConvertTo-Json -Depth 10 | Out-File dist.json" -ForegroundColor Gray
Write-Host "     aws cloudfront update-distribution --id $distributionId --if-match `$config.ETag --distribution-config file://dist.json --profile $AWS_PROFILE" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Wait for deployment (5-10 mins) and delete CloudFront:" -ForegroundColor White
Write-Host "     # Check status until 'Deployed'" -ForegroundColor Gray
Write-Host "     aws cloudfront get-distribution --id $distributionId --query 'Distribution.Status' --profile $AWS_PROFILE" -ForegroundColor Gray
Write-Host ""
Write-Host "     # When status is 'Deployed', delete it" -ForegroundColor Gray
Write-Host "     `$etag = (aws cloudfront get-distribution --id $distributionId --profile $AWS_PROFILE | ConvertFrom-Json).ETag" -ForegroundColor Gray
Write-Host "     aws cloudfront delete-distribution --id $distributionId --if-match `$etag --profile $AWS_PROFILE" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Empty and delete S3 bucket:" -ForegroundColor White
Write-Host "     aws s3 rm s3://$BUCKET_NAME --recursive --profile $AWS_PROFILE" -ForegroundColor Gray
Write-Host "     aws s3 rb s3://$BUCKET_NAME --profile $AWS_PROFILE" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Delete Origin Access Control:" -ForegroundColor White
Write-Host "     `$oacEtag = (aws cloudfront get-origin-access-control --id $oacId --profile $AWS_PROFILE | ConvertFrom-Json).ETag" -ForegroundColor Gray
Write-Host "     aws cloudfront delete-origin-access-control --id $oacId --if-match `$oacEtag --profile $AWS_PROFILE" -ForegroundColor Gray
Write-Host ""
