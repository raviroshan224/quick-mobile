import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Real release signing — see android/key.properties (git-ignored, never
// commit it). Copy android/key.properties.example, fill in your production
// keystore details, and release builds pick it up automatically. Falls back
// to the debug key only when key.properties is absent, so a fresh checkout
// with no keystore configured yet still builds — but loudly, so nobody ships
// a debug-signed release without noticing.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    logger.warn(
        "⚠ android/key.properties not found — release builds will be signed with the " +
        "DEBUG key and are NOT suitable for distribution. See android/key.properties.example."
    )
}

android {
    namespace = "com.salonpos.salon_pos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.salonpos.salon_pos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties configured — falls back to the debug key
                // so local `flutter run --release` / `flutter build apk`
                // still works during development. See the warning logged
                // above; do not distribute a build signed this way.
                signingConfigs.getByName("debug")
            }
        }
    }

    flavorDimensions += "app"
    productFlavors {
        create("dev") {
            dimension = "app"
            applicationIdSuffix = ".dev"
        }
        create("staging") {
            dimension = "app"
            applicationIdSuffix = ".staging"
        }
        create("prod") {
            dimension = "app"
        }
    }
}

flutter {
    source = "../.."
}
