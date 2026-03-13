# ============================================
# عدّل هذه القيم فقط ثم شغّل السكريبت
# EDIT THESE VALUES ONLY, THEN RUN THE SCRIPT
# ============================================

$STORE_PASSWORD = "Agecs@2026#Store"      # كلمة مرور المتجر - غيّرها!
$KEY_PASSWORD = "Agecs@2026#Key"          # كلمة مرور المفتاح - غيّرها!
$YOUR_NAME = "AGECS Development Team"     # اسمك أو اسم الفريق
$CITY = "Ramallah"                        # مدينتك
$STATE = "West Bank"                      # المحافظة
$COUNTRY = "PS"                           # رمز الدولة

# ============================================
# لا تعدّل شيء تحت هذا السطر
# DO NOT EDIT BELOW THIS LINE
# ============================================

Write-Host "=== AGECS ERP - Keystore Generator ===" -ForegroundColor Cyan
Write-Host ""

$keytoolPath = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
$outputDir = $PSScriptRoot
$keystorePath = Join-Path $outputDir "upload-keystore.jks"

if (-not (Test-Path $keytoolPath)) {
    Write-Host "ERROR: keytool not found!" -ForegroundColor Red
    exit 1
}

if (Test-Path $keystorePath) {
    Write-Host "WARNING: Keystore already exists!" -ForegroundColor Yellow
    $backup = Join-Path $outputDir "upload-keystore.jks.backup"
    Copy-Item $keystorePath $backup -Force
    Write-Host "Backup created: $backup" -ForegroundColor Green
    Remove-Item $keystorePath
}

Write-Host "Creating keystore..." -ForegroundColor Green
Write-Host ""

$dname = "CN=$YOUR_NAME, OU=Development, O=AGECS, L=$CITY, S=$STATE, C=$COUNTRY"

try {
    & $keytoolPath -genkey -v `
        -keystore $keystorePath `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -alias upload `
        -dname $dname `
        -storepass $STORE_PASSWORD `
        -keypass $KEY_PASSWORD

    if (Test-Path $keystorePath) {
        Write-Host ""
        Write-Host "=== SUCCESS ===" -ForegroundColor Green
        Write-Host "Keystore created: $keystorePath" -ForegroundColor Green
        Write-Host ""
        
        # Create key.properties
        $keyPropsPath = Join-Path $outputDir "key.properties"
        $keyPropsContent = @"
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
"@
        
        $keyPropsContent | Out-File -FilePath $keyPropsPath -Encoding UTF8 -NoNewline
        Write-Host "Created: key.properties" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "SAVE THESE PASSWORDS:" -ForegroundColor Red
        Write-Host "  Store Password: $STORE_PASSWORD" -ForegroundColor Yellow
        Write-Host "  Key Password: $KEY_PASSWORD" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Next: flutter build appbundle --release" -ForegroundColor Cyan
    }
    else {
        Write-Host "FAILED to create keystore!" -ForegroundColor Red
    }
}
catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
}
