plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.enterprise.bike_showroom_management_system"
    // Pinned rather than inherited from `flutter.compileSdkVersion`:
    // flutter_plugin_android_lifecycle (pulled in by image_picker and
    // file_picker) publishes AAR metadata demanding API 36 or later, and the
    // build fails its metadata check below that.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications, which uses java.time to
        // schedule reminders. Desugaring backports those APIs so scheduled
        // EMI and service notifications work below API 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.enterprise.bike_showroom_management_system"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Firebase Messaging plus the Supabase and PDF stacks push the app
        // past the 64K method limit on older API levels.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Replace with the production signing config before shipping; see
            // docs/DEPLOYMENT.md. Debug keys are used so `--release` runs
            // locally without a keystore.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
