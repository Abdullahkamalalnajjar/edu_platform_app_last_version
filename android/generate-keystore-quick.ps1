# Quick Keystore Generator - Non-Interactive Version
# Edit the variables below, then run this script

Write-Host "=== BOSLA - Quick Keystore Generator ===" -ForegroundColor Cyan
Write-Host ""

# ============================================
# CONFIGURATION - EDIT THESE VALUES
# ============================================
$STORE_PASSWORD = "BoSlAeDuC@123"  # Change this!
$KEY_PASSWORD = "BoSlAeDuC@123"      # Change this!
$YOUR_NAME = "BOSLA Development Team"             # Change this!
$ORG_UNIT = "Development"                 # Optional: Change this
$ORG_NAME = "BOSLA"                       # Optional: Change this
$CITY = "Cairo"                       # Change this!
$STATE = "Cairo"                     # Change this!
$COUNTRY = "EG"                           # Change this! (PS, EG, etc.)
# ============================================

# Passwords are configured, proceeding with keystore generation

# Set the path to keytool
$keytoolPath = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"

# Check if keytool exists
if (-not (Test-Path $keytoolPath)) {
    Write-Host "ERROR: keytool not found at $keytoolPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Trying alternative Java locations..." -ForegroundColor Yellow
    
    # Try to find keytool in Java installation
    $javaHome = $env:JAVA_HOME
    if ($javaHome) {
        $altKeytool = Join-Path $javaHome "bin\keytool.exe"
        if (Test-Path $altKeytool) {
            $keytoolPath = $altKeytool
            Write-Host "Found keytool at: $keytoolPath" -ForegroundColor Green
        }
    }
    
    if (-not (Test-Path $keytoolPath)) {
        Write-Host "Please install Android Studio or set JAVA_HOME environment variable" -ForegroundColor Red
        exit 1
    }
}

# Set the output directory
$outputDir = $PSScriptRoot
$keystorePath = Join-Path $outputDir "upload-keystore.jks"

# Check if keystore already exists
if (Test-Path $keystorePath) {
    Write-Host "WARNING: Keystore already exists at $keystorePath" -ForegroundColor Yellow
    Write-Host "Backing up existing keystore..." -ForegroundColor Yellow
    $backupPath = Join-Path $outputDir "upload-keystore.jks.backup"
    Copy-Item $keystorePath $backupPath -Force
    Write-Host "Backup created at: $backupPath" -ForegroundColor Green
    Remove-Item $keystorePath
}

Write-Host "Creating keystore at: $keystorePath" -ForegroundColor Green
Write-Host ""

# Build the distinguished name
$dname = "CN=$YOUR_NAME, OU=$ORG_UNIT, O=$ORG_NAME, L=$CITY, S=$STATE, C=$COUNTRY"

# Run keytool with all parameters
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
    
    # Check if keystore was created successfully
    if (Test-Path $keystorePath) {
        Write-Host ""
        Write-Host "=== SUCCESS ===" -ForegroundColor Green
        Write-Host "Keystore created successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Keystore location: $keystorePath" -ForegroundColor Cyan
        Write-Host ""
        
        # Automatically create key.properties file
        $keyPropsPath = Join-Path $outputDir "key.properties"
        $keyPropsContent = @"
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
"@
        
        $keyPropsContent | Out-File -FilePath $keyPropsPath -Encoding UTF8 -NoNewline
        Write-Host "Created key.properties file automatically!" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Verify key.properties has correct values: android\key.properties" -ForegroundColor White
        Write-Host "2. Run: flutter build appbundle --release" -ForegroundColor White
        Write-Host ""
        Write-Host "IMPORTANT: Save these credentials securely!" -ForegroundColor Red
        Write-Host "  - Store Password: $STORE_PASSWORD" -ForegroundColor Yellow
        Write-Host "  - Key Password: $KEY_PASSWORD" -ForegroundColor Yellow
        Write-Host "  - Key Alias: upload" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Backup the keystore file to a secure location!" -ForegroundColor Red
        
    }
    else {
        Write-Host ""
        Write-Host "=== FAILED ===" -ForegroundColor Red
        Write-Host "Keystore creation failed. Please check the error messages above." -ForegroundColor Red
    }
}
catch {
    Write-Host ""
    Write-Host "=== ERROR ===" -ForegroundColor Red
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
