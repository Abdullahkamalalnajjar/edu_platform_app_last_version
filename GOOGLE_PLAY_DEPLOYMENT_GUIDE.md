# Google Play Deployment Guide for AGECS ERP

This guide will help you build an App Bundle and configure signing for Google Play deployment.

## Current Status
- **App Name**: AGECS ERP
- **Package Name**: com.mohassan.edu_platform_app
- **Version**: 1.0.0+1
- **Keystore**: Not configured yet ❌

---

## Step 1: Create a Keystore (Upload Key)

### Option A: Using Command Line
Open PowerShell or Command Prompt and run:

```bash
cd d:\edu_platform_app_afterGoogle\edu_platform_app\android

"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Option B: Using Android Studio
1. Open Android Studio
2. Go to **Build** → **Generate Signed Bundle / APK**
3. Select **Android App Bundle**
4. Click **Create new...**
5. Fill in the details:
   - **Key store path**: `d:\edu_platform_app_afterGoogle\edu_platform_app\android\upload-keystore.jks`
   - **Password**: Choose a strong password (SAVE THIS!)
   - **Alias**: upload
   - **Alias Password**: Choose a strong password (SAVE THIS!)
   - **Validity**: 10000 days
   - Fill in your organization details

### Important Information to Save
When creating the keystore, you'll be asked for:
- **Keystore Password**: [SAVE THIS - YOU'LL NEED IT!]
- **Key Alias**: upload
- **Key Password**: [SAVE THIS - YOU'LL NEED IT!]
- **First and Last Name**: Your name or organization
- **Organizational Unit**: Your department (e.g., Development)
- **Organization**: Your company name (e.g., AGECS)
- **City**: Your city
- **State**: Your state/province
- **Country Code**: Your 2-letter country code (e.g., EG for Egypt)

⚠️ **CRITICAL**: Store these passwords securely! If you lose them, you won't be able to update your app on Google Play!

---

## Step 2: Create key.properties File

After creating the keystore, create a file at:
`d:\edu_platform_app_afterGoogle\edu_platform_app\android\key.properties`

With the following content (replace with your actual values):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

⚠️ **IMPORTANT**: Add `key.properties` to `.gitignore` to keep your passwords secure!

---

## Step 3: Update build.gradle.kts

The build.gradle.kts file needs to be updated to use the keystore for release builds.
This will be done automatically after you create the keystore.

---

## Step 4: Update Application ID (Recommended)

Currently using: `com.mohassan.edu_platform_app`

For Google Play, you should use a unique package name like:
- `com.agecs.erp`
- `com.yourcompany.agecsplatform`
- `com.yourdomain.eduplatform`

This needs to be changed in:
1. `android/app/build.gradle.kts` (line 27)
2. `android/app/src/main/AndroidManifest.xml`

---

## Step 5: Build the App Bundle

After completing steps 1-3, run:

```bash
cd d:\edu_platform_app_afterGoogle\edu_platform_app

flutter clean
flutter pub get
flutter build appbundle --release
```

The App Bundle will be created at:
`build\app\outputs\bundle\release\app-release.aab`

---

## Step 6: Verify the Build

Check the App Bundle size and contents:

```bash
# Check file size
ls -l build\app\outputs\bundle\release\app-release.aab

# Verify signing
"C:\Program Files\Android\Android Studio\jbr\bin\jarsigner.exe" -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab
```

---

## Step 7: Prepare for Google Play Console

### Required Assets:
1. **App Icon**: 512x512 PNG (already configured at `assets/images/logo.png`)
2. **Feature Graphic**: 1024x500 PNG
3. **Screenshots**: At least 2 screenshots for each device type
4. **Privacy Policy**: URL to your privacy policy
5. **App Description**: Short and full description

### App Information:
- **App Name**: AGECS ERP
- **Category**: Education
- **Content Rating**: Complete the questionnaire in Play Console
- **Target Audience**: Define your target age group

---

## Step 8: Upload to Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Create a new app or select existing app
3. Go to **Production** → **Create new release**
4. Upload the `app-release.aab` file
5. Fill in release notes
6. Review and roll out

---

## Troubleshooting

### Keystore Issues
- **Lost password?** You'll need to create a new keystore and contact Google Play support
- **File not found?** Make sure the path in `key.properties` is correct

### Build Issues
- Run `flutter doctor` to check for issues
- Run `flutter clean` before building
- Check `android/app/build.gradle.kts` for syntax errors

### Signing Issues
- Verify keystore exists: `ls android\upload-keystore.jks`
- Verify key.properties exists: `ls android\key.properties`
- Check that passwords match

---

## Security Checklist

- [ ] Keystore file created and stored securely
- [ ] Passwords saved in a secure password manager
- [ ] `key.properties` added to `.gitignore`
- [ ] Backup of keystore file created
- [ ] Never commit keystore or passwords to version control

---

## Next Steps After This Guide

1. Create the keystore (Step 1)
2. Let me know when done, and I'll update the build configuration
3. Build the app bundle
4. Upload to Google Play Console

---

## Useful Commands Reference

```bash
# Check Flutter installation
flutter doctor -v

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build App Bundle
flutter build appbundle --release

# Build APK (for testing)
flutter build apk --release

# Check app size
flutter build appbundle --release --analyze-size
```
