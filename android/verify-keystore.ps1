# Keystore Verification Script
# This script checks if your keystore is properly configured

Write-Host "=== AGECS ERP - Keystore Verification ===" -ForegroundColor Cyan
Write-Host ""

$androidDir = $PSScriptRoot
$keystorePath = Join-Path $androidDir "upload-keystore.jks"
$keyPropsPath = Join-Path $androidDir "key.properties"

$allGood = $true

# Check 1: Keystore file exists
Write-Host "Checking keystore file..." -NoNewline
if (Test-Path $keystorePath) {
    Write-Host " ✓ FOUND" -ForegroundColor Green
    $keystoreSize = (Get-Item $keystorePath).Length
    Write-Host "  Location: $keystorePath" -ForegroundColor Gray
    Write-Host "  Size: $keystoreSize bytes" -ForegroundColor Gray
}
else {
    Write-Host " ✗ NOT FOUND" -ForegroundColor Red
    Write-Host "  Expected location: $keystorePath" -ForegroundColor Yellow
    $allGood = $false
}
Write-Host ""

# Check 2: key.properties file exists
Write-Host "Checking key.properties file..." -NoNewline
if (Test-Path $keyPropsPath) {
    Write-Host " ✓ FOUND" -ForegroundColor Green
    Write-Host "  Location: $keyPropsPath" -ForegroundColor Gray
    
    # Read and validate key.properties content
    $keyProps = Get-Content $keyPropsPath -Raw
    
    Write-Host "  Checking properties..." -ForegroundColor Gray
    
    if ($keyProps -match "storePassword=(.+)") {
        $storePass = $matches[1].Trim()
        if ($storePass -eq "YOUR_KEYSTORE_PASSWORD_HERE" -or $storePass -eq "") {
            Write-Host "    ✗ storePassword not set" -ForegroundColor Red
            $allGood = $false
        }
        else {
            Write-Host "    ✓ storePassword is set" -ForegroundColor Green
        }
    }
    else {
        Write-Host "    ✗ storePassword missing" -ForegroundColor Red
        $allGood = $false
    }
    
    if ($keyProps -match "keyPassword=(.+)") {
        $keyPass = $matches[1].Trim()
        if ($keyPass -eq "YOUR_KEY_PASSWORD_HERE" -or $keyPass -eq "") {
            Write-Host "    ✗ keyPassword not set" -ForegroundColor Red
            $allGood = $false
        }
        else {
            Write-Host "    ✓ keyPassword is set" -ForegroundColor Green
        }
    }
    else {
        Write-Host "    ✗ keyPassword missing" -ForegroundColor Red
        $allGood = $false
    }
    
    if ($keyProps -match "keyAlias=(.+)") {
        Write-Host "    ✓ keyAlias is set" -ForegroundColor Green
    }
    else {
        Write-Host "    ✗ keyAlias missing" -ForegroundColor Red
        $allGood = $false
    }
    
    if ($keyProps -match "storeFile=(.+)") {
        Write-Host "    ✓ storeFile is set" -ForegroundColor Green
    }
    else {
        Write-Host "    ✗ storeFile missing" -ForegroundColor Red
        $allGood = $false
    }
    
}
else {
    Write-Host " ✗ NOT FOUND" -ForegroundColor Red
    Write-Host "  Expected location: $keyPropsPath" -ForegroundColor Yellow
    Write-Host "  You need to create this file from key.properties.template" -ForegroundColor Yellow
    $allGood = $false
}
Write-Host ""

# Check 3: build.gradle.kts is configured
Write-Host "Checking build.gradle.kts configuration..." -NoNewline
$buildGradlePath = Join-Path $androidDir "app\build.gradle.kts"
if (Test-Path $buildGradlePath) {
    $buildGradle = Get-Content $buildGradlePath -Raw
    if ($buildGradle -match "signingConfigs" -and $buildGradle -match "keystoreProperties") {
        Write-Host " ✓ CONFIGURED" -ForegroundColor Green
    }
    else {
        Write-Host " ✗ NOT CONFIGURED" -ForegroundColor Red
        $allGood = $false
    }
}
else {
    Write-Host " ✗ FILE NOT FOUND" -ForegroundColor Red
    $allGood = $false
}
Write-Host ""

# Check 4: Try to verify keystore with keytool (if passwords are available)
if ((Test-Path $keystorePath) -and (Test-Path $keyPropsPath)) {
    Write-Host "Attempting to verify keystore with keytool..." -ForegroundColor Cyan
    
    $keytoolPath = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
    if (Test-Path $keytoolPath) {
        # Read password from key.properties
        $keyProps = Get-Content $keyPropsPath -Raw
        if ($keyProps -match "storePassword=(.+)") {
            $storePass = $matches[1].Trim()
            if ($storePass -ne "YOUR_KEYSTORE_PASSWORD_HERE" -and $storePass -ne "") {
                try {
                    $output = & $keytoolPath -list -v -keystore $keystorePath -alias upload -storepass $storePass 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✓ Keystore is valid and accessible" -ForegroundColor Green
                        
                        # Extract and display certificate info
                        if ($output -match "Valid from: (.+?) until: (.+?)[\r\n]") {
                            Write-Host "  Valid from: $($matches[1])" -ForegroundColor Gray
                            Write-Host "  Valid until: $($matches[2])" -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-Host "  ✗ Failed to verify keystore" -ForegroundColor Red
                        Write-Host "  Error: $output" -ForegroundColor Yellow
                        $allGood = $false
                    }
                }
                catch {
                    Write-Host "  ✗ Error verifying keystore: $_" -ForegroundColor Red
                    $allGood = $false
                }
            }
        }
    }
    else {
        Write-Host "  ⚠ keytool not found, skipping verification" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Final summary
Write-Host "========================================" -ForegroundColor Cyan
if ($allGood) {
    Write-Host "✓ ALL CHECKS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your keystore is properly configured." -ForegroundColor Green
    Write-Host "You can now build your release app bundle:" -ForegroundColor Cyan
    Write-Host "  flutter build appbundle --release" -ForegroundColor White
}
else {
    Write-Host "✗ SOME CHECKS FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the issues above before building." -ForegroundColor Yellow
    Write-Host "See KEYSTORE_SETUP_GUIDE.md for detailed instructions." -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
