import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val alphaKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val alphaKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val alphaKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
val alphaKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val hasAlphaSigning = listOf(
    alphaKeystorePath, alphaKeystorePassword, alphaKeyAlias, alphaKeyPassword
).all { !it.isNullOrBlank() }

android {
    namespace = "dev.pyrearms.pyrechat_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.pyrearms.pyrechat_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (hasAlphaSigning) {
        signingConfigs.create("alpha") {
            storeFile = File(alphaKeystorePath!!)
            storePassword = alphaKeystorePassword
            keyAlias = alphaKeyAlias
            keyPassword = alphaKeyPassword
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        release {
            // Local release builds retain the existing debug signing behavior.
            // Alpha CI supplies a stable keystore through environment secrets.
            signingConfig = if (hasAlphaSigning) signingConfigs.getByName("alpha")
                else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

