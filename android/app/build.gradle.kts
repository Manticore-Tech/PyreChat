import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val googleServicesFile = file("google-services.json")
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseBuildRequested && !googleServicesFile.exists()) {
    throw GradleException(
        "Release builds require android/app/google-services.json so Firebase Cloud Messaging is enabled. " +
            "CI injects it from FIREBASE_ANDROID_GOOGLE_SERVICES_JSON."
    )
}

if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val alphaKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val alphaKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val alphaKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
val alphaKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val hasAlphaSigning = listOf(
    alphaKeystorePath, alphaKeystorePassword, alphaKeyAlias, alphaKeyPassword
).all { !it.isNullOrBlank() }

val playReleaseBundleRequested = gradle.startParameter.taskNames.any {
    it.contains("bundle", ignoreCase = true) &&
        it.contains("release", ignoreCase = true)
}

if (playReleaseBundleRequested && !hasAlphaSigning) {
    throw GradleException(
        "Google Play release bundles require stable Android signing. " +
            "Set ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, " +
            "ANDROID_KEY_ALIAS, and ANDROID_KEY_PASSWORD before building a release AAB."
    )
}

val cameraKitProperties = Properties()
val cameraKitPropertiesFile = rootProject.file("camerakit.properties")
if (cameraKitPropertiesFile.exists()) {
    cameraKitPropertiesFile.inputStream().use(cameraKitProperties::load)
}

fun cameraKitValue(environmentName: String, propertyName: String): String =
    System.getenv(environmentName)?.trim()?.takeIf { it.isNotEmpty() }
        ?: cameraKitProperties.getProperty(propertyName)?.trim().orEmpty()

fun quotedBuildConfig(value: String): String = "\"" + value + "\""

val cameraKitApiToken = cameraKitValue("CAMERA_KIT_API_TOKEN", "CAMERA_KIT_API_TOKEN")
val cameraKitLensGroupIds =
    cameraKitValue("CAMERA_KIT_LENS_GROUP_IDS", "CAMERA_KIT_LENS_GROUP_IDS")
        .ifBlank {
            cameraKitValue("CAMERA_KIT_LENS_GROUP_ID", "CAMERA_KIT_LENS_GROUP_ID")
        }
val cameraKitInternalEval =
    cameraKitValue("CAMERA_KIT_INTERNAL_EVAL", "CAMERA_KIT_INTERNAL_EVAL")
        .equals("true", ignoreCase = true)
val cameraKitConfigured =
    cameraKitInternalEval &&
        cameraKitApiToken.isNotBlank() &&
        cameraKitLensGroupIds.isNotBlank()

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

android {
    namespace = "dev.pyrearms.pyrechat_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.pyrearms.pyrechat_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["cameraKitApiToken"] = cameraKitApiToken
        buildConfigField(
            "String",
            "CAMERA_KIT_API_TOKEN",
            quotedBuildConfig(cameraKitApiToken),
        )
        buildConfigField(
            "String",
            "CAMERA_KIT_LENS_GROUP_IDS",
            quotedBuildConfig(cameraKitLensGroupIds),
        )
        buildConfigField(
            "boolean",
            "CAMERA_KIT_INTERNAL_EVAL",
            cameraKitInternalEval.toString(),
        )
        buildConfigField(
            "boolean",
            "CAMERA_KIT_CONFIGURED",
            cameraKitConfigured.toString(),
        )
    }

    buildFeatures {
        buildConfig = true
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
        release {
            // Direct-download release APKs may retain the existing local debug-signing
            // fallback, but release AABs are guarded above and require stable signing.
            // CI supplies the Play signing keystore through environment secrets.
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
    implementation("com.snap.camerakit:support-camera-activity:1.50.0")

    // Debug builds may compile without local Firebase configuration for ordinary
    // UI development. Release builds are blocked above unless FCM is configured.
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
    implementation("com.google.firebase:firebase-messaging")
}
