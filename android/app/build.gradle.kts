import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val nutriSenseApplicationId = providers
    .gradleProperty("NUTRISENSE_APPLICATION_ID")
    .orElse("com.example.nutrisense")
    .get()

val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseTaskRequested && nutriSenseApplicationId.startsWith("com.example.")) {
    throw GradleException(
        "Release blocked: set an institution-owned NUTRISENSE_APPLICATION_ID " +
            "in android/gradle.properties or with -P before releasing.",
    )
}

android {
    namespace = "com.example.nutrisense"
    compileSdk = flutter.compileSdkVersion
    // Installed and explicitly pinned; satisfies plugins requiring NDK 27+.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = nutriSenseApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO(RELEASE): Configure an institution-owned keystore through
            // CI secrets. Debug signing is deliberately forbidden for release.
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
