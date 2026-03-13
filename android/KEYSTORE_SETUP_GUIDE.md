# Keystore Configuration Guide for AGECS ERP

This guide will help you create and configure a keystore for signing your Android app for Google Play release.

## Prerequisites

- Java Development Kit (JDK) installed
- Android Studio installed (for keytool)

## Step 1: Generate the Keystore

You have two options:

### Option A: Using the PowerShell Script (Interactive)

Run the existing script:
```powershell
cd android
powershell -ExecutionPolicy Bypass -File .\generate-keystore.ps1
```

Follow the prompts to enter:
- Keystore password (minimum 6 characters)
- Key password (minimum 6 characters)
- Your name
- Organizational unit (e.g., "Development")
- Organization name (e.g., "AGECS")
- City
- State/Province
- Country code (2 letters, e.g., "PS" for Palestine, "EG" for Egypt)

### Option B: Using Command Line Directly (Non-Interactive)

Open PowerShell in the `android` directory and run:

```powershell
# Set your keytool path (adjust if needed)
$keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"

# Generate keystore with all information in one command
& $keytool -genkey -v `
  -keystore upload-keystore.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload `
  -dname "CN=Your Name, OU=Development, O=AGECS, L=Your City, S=Your State, C=PS" `
  -storepass "YOUR_STORE_PASSWORD" `
  -keypass "YOUR_KEY_PASSWORD"
```

**Replace the following:**
- `Your Name` - Your full name
- `Your City` - Your city
- `Your State` - Your state/province
- `C=PS` - Your country code (PS for Palestine, EG for Egypt, etc.)
- `YOUR_STORE_PASSWORD` - Choose a strong password (save it!)
- `YOUR_KEY_PASSWORD` - Choose a strong password (save it!)

## Step 2: Create key.properties File

1. Copy the template file:
   ```powershell
   Copy-Item key.properties.template key.properties
   ```

2. Edit `android/key.properties` with your actual passwords:
   ```properties
   storePassword=YOUR_ACTUAL_KEYSTORE_PASSWORD
   keyPassword=YOUR_ACTUAL_KEY_PASSWORD
   keyAlias=upload
   storeFile=upload-keystore.jks
   ```

## Step 3: Verify Configuration

Check that you have:
- ✅ `android/upload-keystore.jks` file exists
- ✅ `android/key.properties` file exists with correct passwords
- ✅ `android/app/build.gradle.kts` is configured (already done)

## Step 4: Build the App Bundle

From the project root directory:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

The signed app bundle will be created at:
`build/app/outputs/bundle/release/app-release.aab`

## Important Security Notes

⚠️ **CRITICAL - Save These Securely:**
1. **Keystore file** (`upload-keystore.jks`) - Back this up in a secure location
2. **Keystore password** - Save in a password manager
3. **Key password** - Save in a password manager
4. **Key alias** - `upload` (default)

⚠️ **Never commit to Git:**
- `key.properties` (already in .gitignore)
- `upload-keystore.jks` (already in .gitignore)

If you lose the keystore or passwords, you **cannot update your app** on Google Play!

## Troubleshooting

### keytool not found
If keytool is not found, locate it in your Android Studio installation:
- Windows: `C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`
- Or use Java JDK: `C:\Program Files\Java\jdk-XX\bin\keytool.exe`

### Build fails with signing error
1. Verify `key.properties` has correct passwords
2. Verify `upload-keystore.jks` exists in `android/` directory
3. Check that passwords don't contain special characters that need escaping

### Verify keystore information
```powershell
keytool -list -v -keystore upload-keystore.jks -alias upload
```

## Next Steps

After successfully building the app bundle:
1. Test the release build on a physical device
2. Upload to Google Play Console
3. Follow the Google Play deployment guide

For more details, see: `GOOGLE_PLAY_DEPLOYMENT_GUIDE.md`
