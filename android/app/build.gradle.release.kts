// ═══════════════════════════════════════════════════════════════════════════════
// android/app/build.gradle.release.kts
// NutriSense — Release APK/AAB Yapılandırması
//
// Bu dosya mevcut build.gradle'a eklenmesi gereken release yapılandırmasını
// içerir. Mevcut build.gradle'ın android {} bloğuna entegre edin.
// ═══════════════════════════════════════════════════════════════════════════════

/*
 * ═══════════════════════════════════════════════════════════════
 * 1. KEYSTORE OLUŞTURMA (Terminal komutu)
 * ═══════════════════════════════════════════════════════════════
 *
 * keytool -genkey -v \
 *   -keystore nutrisense-release-key.jks \
 *   -keyalg RSA \
 *   -keysize 2048 \
 *   -validity 10000 \
 *   -alias nutrisense \
 *   -storepass <GÜÇLÜ_ŞİFRE> \
 *   -keypass <GÜÇLÜ_ŞİFRE>
 *
 * Not: .jks dosyasını GİT'E EKLEME! .gitignore'a ekle.
 *
 * ═══════════════════════════════════════════════════════════════
 * 2. android/key.properties (GİT'E EKLEME!)
 * ═══════════════════════════════════════════════════════════════
 *
 * storePassword=<GÜÇLÜ_ŞİFRE>
 * keyPassword=<GÜÇLÜ_ŞİFRE>
 * keyAlias=nutrisense
 * storeFile=../nutrisense-release-key.jks
 *
 * ═══════════════════════════════════════════════════════════════
 * 3. build.gradle ÜST KISMA EKLE
 * ═══════════════════════════════════════════════════════════════
 */

// def keystoreProperties = new Properties()
// def keystorePropertiesFile = rootProject.file('key.properties')
// if (keystorePropertiesFile.exists()) {
//     keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
// }

/*
 * ═══════════════════════════════════════════════════════════════
 * 4. android {} BLOĞUNA EKLE
 * ═══════════════════════════════════════════════════════════════
 */

// android {
//     compileSdkVersion 34
//     ndkVersion "25.2.9519653"
//
//     defaultConfig {
//         applicationId "com.nutrisense.app"
//         minSdkVersion 24
//         targetSdkVersion 34
//         versionCode 1
//         versionName "1.0.0"
//
//         // TFLite model assets'te kalmalı
//         aaptOptions {
//             noCompress "tflite"
//         }
//     }
//
//     signingConfigs {
//         release {
//             keyAlias keystoreProperties['keyAlias']
//             keyPassword keystoreProperties['keyPassword']
//             storeFile keystoreProperties['storeFile'] ?
//                 file(keystoreProperties['storeFile']) : null
//             storePassword keystoreProperties['storePassword']
//         }
//     }
//
//     buildTypes {
//         release {
//             signingConfig signingConfigs.release
//             minifyEnabled true
//             shrinkResources true
//             proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
//                           'proguard-rules.pro'
//
//             // Performans optimizasyonu
//             ndk {
//                 debugSymbolLevel 'SYMBOL_TABLE'
//             }
//         }
//
//         debug {
//             signingConfig signingConfigs.debug
//             minifyEnabled false
//             shrinkResources false
//         }
//     }
//
//     // AAB (App Bundle) — Play Store tercih eder
//     bundle {
//         language { enableSplit = true }
//         density { enableSplit = true }
//         abi { enableSplit = true }
//     }
// }

/*
 * ═══════════════════════════════════════════════════════════════
 * 5. BUILD KOMUTLARI
 * ═══════════════════════════════════════════════════════════════
 *
 * // Debug APK
 * flutter build apk --debug
 *
 * // Release APK (doğrudan yükleme için)
 * flutter build apk --release
 *
 * // Release AAB (Google Play için — ÖNERİLEN)
 * flutter build appbundle --release
 *
 * // APK boyutunu kontrol et
 * flutter build apk --analyze-size
 *
 * Çıktı konumları:
 *   APK: build/app/outputs/flutter-apk/app-release.apk
 *   AAB: build/app/outputs/bundle/release/app-release.aab
 */
