// ═══════════════════════════════════════════════════════════════════════════════
// android/app/proguard-rules.pro
// NutriSense — minimal R8 rules for dependencies actually bundled today.
// Flutter plugins publish their own consumer rules. Do not claim or preserve
// Firebase, Google Vision or TFLite classes until those SDKs are really added.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
