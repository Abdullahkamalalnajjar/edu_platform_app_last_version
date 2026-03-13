# 🔐 Keystore Configuration - Quick Start Guide

## Current Status
- ❌ Keystore file: **NOT CREATED YET**
- ❌ key.properties: **NOT CREATED YET**
- ✅ build.gradle.kts: **ALREADY CONFIGURED**

## 📋 What You Need to Do

### Option 1: Quick Setup (Recommended - 5 minutes)

1. **Edit the quick generator script:**
   - Open `android/generate-keystore-quick.ps1`
   - Change these values at the top:
     ```powershell
     $STORE_PASSWORD = "YourStorePassword123"  # Change to a strong password
     $KEY_PASSWORD = "YourKeyPassword123"      # Change to a strong password
     $YOUR_NAME = "Your Full Name"             # Your name
     $CITY = "Your City"                       # e.g., "Ramallah"
     $STATE = "Your State"                     # e.g., "West Bank"
     $COUNTRY = "PS"                           # e.g., "PS" for Palestine
     ```

2. **Run the script:**
   ```powershell
   cd android
   powershell -ExecutionPolicy Bypass -File .\generate-keystore-quick.ps1
   ```

3. **Done!** The script will automatically:
   - Create `upload-keystore.jks`
   - Create `key.properties` with your passwords
   - Show you a success message

### Option 2: Manual Command (Advanced)

Run this command in PowerShell (replace the values):

```powershell
cd android

& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v `
  -keystore upload-keystore.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload `
  -dname "CN=Your Name, OU=Development, O=AGECS, L=Your City, S=Your State, C=PS" `
  -storepass "YourStorePassword" `
  -keypass "YourKeyPassword"
```

Then create `key.properties`:
```properties
storePassword=YourStorePassword
keyPassword=YourKeyPassword
keyAlias=upload
storeFile=upload-keystore.jks
```

### Option 3: Interactive (Original Script)

```powershell
cd android
powershell -ExecutionPolicy Bypass -File .\generate-keystore.ps1
```

Follow the prompts to enter your information.

## 🔒 Important Security Notes

### SAVE THESE SECURELY:
1. **Keystore file** (`upload-keystore.jks`) - Backup to a secure location
2. **Store password** - Save in a password manager
3. **Key password** - Save in a password manager

### ⚠️ WARNING:
- If you lose the keystore or passwords, you **CANNOT** update your app on Google Play
- You would need to publish a new app with a different package name
- **NEVER** commit `key.properties` or `upload-keystore.jks` to Git (already in .gitignore)

## 📱 After Creating the Keystore

### 1. Verify the setup:
```powershell
cd android
dir upload-keystore.jks
dir key.properties
```

Both files should exist.

### 2. Build the release app bundle:
```powershell
cd ..  # Back to project root
flutter clean
flutter pub get
flutter build appbundle --release
```

### 3. Find your app bundle:
The signed `.aab` file will be at:
```
build/app/outputs/bundle/release/app-release.aab
```

### 4. Upload to Google Play Console:
- Go to Google Play Console
- Navigate to your app
- Go to "Release" → "Production" (or Testing)
- Upload the `app-release.aab` file

## 🛠️ Troubleshooting

### "keytool not found"
The keytool path might be different on your system. Try these locations:
- `C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`
- `C:\Program Files\Java\jdk-XX\bin\keytool.exe`
- Or set `JAVA_HOME` environment variable

### "Build fails with signing error"
1. Check that `key.properties` exists in `android/` directory
2. Verify passwords in `key.properties` are correct
3. Verify `upload-keystore.jks` exists in `android/` directory

### "Verify keystore information"
```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" `
  -list -v -keystore upload-keystore.jks -alias upload
```

Enter your store password when prompted.

## 📚 Additional Resources

- `KEYSTORE_SETUP_GUIDE.md` - Detailed setup guide
- `GOOGLE_PLAY_DEPLOYMENT_GUIDE.md` - Full deployment guide
- `DEPLOYMENT_CHECKLIST.md` - Pre-deployment checklist

## 🎯 Next Steps

1. ✅ Create keystore (you are here)
2. ⬜ Build release app bundle
3. ⬜ Test on physical device
4. ⬜ Upload to Google Play Console
5. ⬜ Submit for review

---

**Need help?** Check the detailed guides in the `android/` directory.
