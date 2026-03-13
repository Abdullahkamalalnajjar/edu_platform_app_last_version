# Script to generate keystore for Android app signing
# Run this script from PowerShell

Write-Host "=== AGECS ERP - Keystore Generation Script ===" -ForegroundColor Cyan
Write-Host ""

# Set the path to keytool
$keytoolPath = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"

# Check if keytool exists
if (-not (Test-Path $keytoolPath)) {
    Write-Host "ERROR: keytool not found at $keytoolPath" -ForegroundColor Red
    Write-Host "Please update the path in this script or install Android Studio" -ForegroundColor Yellow
    exit 1
}

# Set the output directory
$outputDir = "d:\edu_platform_app_afterGoogle\edu_platform_app\android"
$keystorePath = Join-Path $outputDir "upload-keystore.jks"

# Check if keystore already exists
if (Test-Path $keystorePath) {
    Write-Host "WARNING: Keystore already exists at $keystorePath" -ForegroundColor Yellow
    $overwrite = Read-Host "Do you want to overwrite it? (yes/no)"
    if ($overwrite -ne "yes") {
        Write-Host "Aborted." -ForegroundColor Red
        exit 0
    }
    Remove-Item $keystorePath
}

Write-Host "Creating keystore at: $keystorePath" -ForegroundColor Green
Write-Host ""
Write-Host "You will be asked to provide the following information:" -ForegroundColor Yellow
Write-Host "  1. Keystore password (SAVE THIS!)" -ForegroundColor Yellow
Write-Host "  2. Key password (SAVE THIS!)" -ForegroundColor Yellow
Write-Host "  3. First and Last Name" -ForegroundColor Yellow
Write-Host "  4. Organizational Unit (e.g., Development)" -ForegroundColor Yellow
Write-Host "  5. Organization (e.g., AGECS)" -ForegroundColor Yellow
Write-Host "  6. City" -ForegroundColor Yellow
Write-Host "  7. State/Province" -ForegroundColor Yellow
Write-Host "  8. Country Code (2 letters, e.g., EG)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""

# Run keytool
& $keytoolPath -genkey -v -keystore $keystorePath -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Check if keystore was created successfully
if (Test-Path $keystorePath) {
    Write-Host ""
    Write-Host "=== SUCCESS ===" -ForegroundColor Green
    Write-Host "Keystore created successfully at: $keystorePath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Copy 'android\key.properties.template' to 'android\key.properties'" -ForegroundColor White
    Write-Host "2. Edit 'android\key.properties' and fill in your passwords" -ForegroundColor White
    Write-Host "3. Run: flutter build appbundle --release" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT: Save your passwords in a secure location!" -ForegroundColor Red
} else {
    Write-Host ""
    Write-Host "=== FAILED ===" -ForegroundColor Red
    Write-Host "Keystore creation failed. Please check the error messages above." -ForegroundColor Red
}
