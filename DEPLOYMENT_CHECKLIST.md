# Google Play Deployment Checklist

## ✅ Completed
- [x] Build configuration updated to support keystore signing
- [x] .gitignore configured to exclude sensitive files
- [x] Template files created for keystore setup

## 📋 To Do

### 1. Create Keystore
- [ ] Run the keystore generation script:
  ```powershell
  cd d:\edu_platform_app_afterGoogle\edu_platform_app\android
  .\generate-keystore.ps1
  ```
  OR manually create using Android Studio (Build → Generate Signed Bundle)

### 2. Configure Signing
- [ ] Copy `android\key.properties.template` to `android\key.properties`
- [ ] Edit `android\key.properties` with your actual passwords
- [ ] Verify keystore file exists: `android\upload-keystore.jks`

### 3. Update Package Name (Recommended)
- [ ] Change `com.mohassan.edu_platform_app` to your unique package name
- [ ] Update in: `android\app\build.gradle.kts` (line 17)
- [ ] Update in: `android\app\src\main\AndroidManifest.xml`

### 4. Build App Bundle
- [ ] Run: `flutter clean`
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter build appbundle --release`
- [ ] Verify output at: `build\app\outputs\bundle\release\app-release.aab`

### 5. Prepare Play Store Assets
- [ ] App icon (512x512 PNG) - ✅ Already have at `assets/images/logo.png`
- [ ] Feature graphic (1024x500 PNG)
- [ ] Screenshots (at least 2 per device type)
- [ ] Privacy policy URL
- [ ] App description (short and full)

### 6. Google Play Console
- [ ] Create app in Play Console
- [ ] Upload app bundle
- [ ] Fill in store listing
- [ ] Complete content rating questionnaire
- [ ] Set up pricing and distribution
- [ ] Submit for review

## 🔐 Security Reminders
- [ ] Save keystore passwords in password manager
- [ ] Create backup of keystore file
- [ ] Never commit `key.properties` to git
- [ ] Never commit `*.jks` or `*.keystore` files to git

## 📝 Important Information to Save
- Keystore Password: _______________
- Key Alias: upload
- Key Password: _______________
- Keystore Location: `d:\edu_platform_app_afterGoogle\edu_platform_app\android\upload-keystore.jks`

## 🚀 Quick Commands

```bash
# Navigate to project
cd d:\edu_platform_app_afterGoogle\edu_platform_app

# Clean and get dependencies
flutter clean
flutter pub get

# Build release bundle
flutter build appbundle --release

# Build release APK (for testing)
flutter build apk --release

# Check build size
flutter build appbundle --release --analyze-size

# Verify signing
jarsigner -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab
```

## 📚 Resources
- [Google Play Console](https://play.google.com/console)
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- Full guide: See `GOOGLE_PLAY_DEPLOYMENT_GUIDE.md`
