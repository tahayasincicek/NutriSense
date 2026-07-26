import java.util.Properties
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
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties =
    Properties().apply {
        if (keyPropertiesFile.exists()) {
            keyPropertiesFile.inputStream().use(::load)
        }
    }

if (releaseTaskRequested && nutriSenseApplicationId.startsWith("com.example.")) {
    throw GradleException(
        "Release blocked: set an institution-owned NUTRISENSE_APPLICATION_ID " +
            "in android/gradle.properties or with -P before releasing.",
    )
}
if (releaseTaskRequested && !keyPropertiesFile.exists()) {
    throw GradleException(
        "Release blocked: android/key.properties is missing. Follow " +
            "docs/android_release_runbook.md; never commit the upload key.",
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
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "NutriSense"
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["appLabel"] = "NutriSense Dev"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            manifestPlaceholders["appLabel"] = "NutriSense Staging"
        }
        create("prod") {
            dimension = "environment"
            manifestPlaceholders["appLabel"] = "NutriSense"
        }
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                val requiredKeys =
                    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
                val missing =
                    requiredKeys.filter { keyProperties.getProperty(it).isNullOrBlank() }
                if (missing.isNotEmpty()) {
                    throw GradleException(
                        "Release signing configuration is incomplete: ${missing.joinToString()}.",
                    )
                }
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = signingConfigs.findByName("release")
        }
    }

    bundle {
        language.enableSplit = true
        density.enableSplit = true
        abi.enableSplit = true
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
