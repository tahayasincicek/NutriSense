// ═══════════════════════════════════════════════════════════════════════════════
// android/app/proguard-rules.pro
// NutriSense — ProGuard / R8 Kuralları
//
// TFLite modeli, Google Vision, ve JSON serileştirme koruması.
// ═══════════════════════════════════════════════════════════════════════════════

// ── TensorFlow Lite Koruma ──
-keep class org.tensorflow.** { *; }
-keepclassmembers class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

// TFLite model dosyasını korut (assets'ten yükleniyor)
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }

// ── Google Cloud Vision ──
-keep class com.google.api.** { *; }
-keep class com.google.cloud.vision.** { *; }
-dontwarn com.google.api.**

// ── Firebase Crashlytics ──
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keep class com.google.firebase.crashlytics.** { *; }

// ── JSON / Gson ──
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

// ── Flutter ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

// ── Camera Plugin ──
-keep class io.flutter.plugins.camera.** { *; }

// ── Flutter TTS ──
-keep class com.tundralabs.fluttertts.** { *; }

// ── Speech to Text ──
-keep class com.csdcorp.speech_to_text.** { *; }

// ── SharedPreferences ──
-keep class io.flutter.plugins.sharedpreferences.** { *; }

// ── Genel ──
-optimizationpasses 5
-dontusemixedcaseclassnames
-verbose
-dontskipnonpubliclibraryclasses
-dontskipnonpubliclibraryclassmembers
