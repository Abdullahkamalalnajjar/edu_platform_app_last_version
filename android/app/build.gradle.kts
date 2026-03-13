import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// =====================
// قراءة local.properties
// =====================
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toInt() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

// =====================
// قراءة key.properties
// =====================
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.boslaedu.edu_platform"
    compileSdk = 36
//    ndkVersion = "25.1.8937393" // عدّل حسب مشروعك
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.boslaedu.edu_platform"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        multiDexEnabled = true

        vectorDrawables.useSupportLibrary = true

        ndk {
            abiFilters += setOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }


    kotlinOptions {
        jvmTarget = "17"
    }
//    kotlin {
//        android {
//            compilerOptions {
//                jvmTarget = "17"
//            }
//        }
//    }

    buildFeatures {
        buildConfig = true
        viewBinding = true
    }

    signingConfigs {
        // تعديل الـ debug الموجود
        getByName("debug") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword ="123456"// keystoreProperties.getProperty("storePassword")
            } else {
                storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }

        // إنشاء release جديد (غير موجود افتراضيًا)
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = requireNotNull(keystoreProperties.getProperty("keyAlias")) {
                    "Missing keyAlias in key.properties"
                }
                keyPassword = "123456"//requireNotNull(keystoreProperties.getProperty("keyPassword")) {
//                    "Missing keyPassword in key.properties"
//                }
                storeFile = file(requireNotNull(keystoreProperties.getProperty("storeFile")) {
                    "Missing storeFile in key.properties"
                })
                storePassword = "123456" // requireNotNull(keystoreProperties.getProperty("storePassword")) {
//                    "Missing storePassword in key.properties"
//                }
            } else {
                throw GradleException("key.properties file not found, release signing impossible")
            }
        }
//        create("release") {
//            if (keystorePropertiesFile.exists()) {
//                keyAlias = keystoreProperties.getProperty("keyAlias")
//                keyPassword = keystoreProperties.getProperty("keyPassword")
//                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
//                storePassword = keystoreProperties.getProperty("storePassword")
//            }
//        }
    }


    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }

        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            isCrunchPngs = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "**/kotlin/**",
                "**/okhttp3/**"
            )
            pickFirsts += setOf(
                "lib/x86/libc++_shared.so",
                "lib/x86_64/libc++_shared.so",
                "lib/armeabi-v7a/libc++_shared.so",
                "lib/arm64-v8a/libc++_shared.so"
            )
        }
    }

    lint {
        disable += "InvalidPackage"
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
