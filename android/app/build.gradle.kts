import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing config, loaded from android/key.properties (git-ignored —
// see .gitignore). Falls back to no release signing config if the file is
// absent (e.g. a fresh checkout before the keystore has been generated).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.jcmart.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.jcmart.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Release builds are signed with the upload keystore from
            // android/key.properties — and ONLY that. There is deliberately no
            // debug-key fallback any more: a silently debug-signed "release"
            // can't be uploaded to Play and is a security problem if shipped
            // elsewhere. Building a release without the keystore now fails
            // (see the guard below the android block).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Fail closed: refuse to build a release artifact without the keystore. Only
// assemble/bundle tasks are checked, so debug runs and analysis are unaffected.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any {
        it.name.contains("Release", ignoreCase = true) &&
            (it.name.startsWith("assemble") || it.name.startsWith("bundle"))
    }
    if (buildingRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "android/key.properties (upload keystore: keyAlias, keyPassword, storeFile, " +
                "storePassword) is missing — refusing to build a release with debug signing."
        )
    }
}

flutter {
    source = "../.."
}
