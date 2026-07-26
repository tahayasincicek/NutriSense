// =============================================================================
// lib/core/utils/crash_reporter.dart
// NutriSense — yalnız yerel/debug hata köprüsü
//
// Firebase Crashlytics bu projede yapılandırılmamış ve devre dışıdır. Bu sınıf
// uzaktaki bir sağlayıcıya veri göndermez. İleride uzaktan crash reporting
// eklenecekse kullanıcı bilgilendirmesi/onayı, veri minimizasyonu, retention,
// yurtdışı aktarım değerlendirmesi ve platform yapılandırması ayrıca gerekir.
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Aşağıdaki örnek importlar bilinçli olarak devre dışıdır:
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// import 'package:firebase_core/firebase_core.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CRASH REPORTER SERVİSİ
// ═══════════════════════════════════════════════════════════════════════════════

class CrashReporter {
  CrashReporter._();
  static final instance = CrashReporter._();

  bool _initialized = false;
  String _currentScreen = 'unknown';
  String _appVersion = '1.0.0';

  /// Yerel/global hata yakalayıcılarını kur; uzaktan raporlama yapmaz.
  ///
  /// Kullanım (main.dart içinde):
  /// ```dart
  /// void main() async {
  ///   await CrashReporter.instance.initialize(
  ///     appRunner: () => runApp(const NutriSenseApp()),
  ///   );
  /// }
  /// ```
  Future<void> initialize({
    required VoidCallback appRunner,
    String appVersion = '1.0.0',
  }) async {
    _appVersion = appVersion;

    // ── Firebase başlat ──
    // WidgetsFlutterBinding.ensureInitialized();
    // await Firebase.initializeApp();

    // ── Crashlytics yapılandırması ──
    // final crashlytics = FirebaseCrashlytics.instance;

    // KVKK: Kullanıcı kimliği KAYDETMİYORUZ
    // crashlytics.setUserIdentifier(''); // Boş bırak

    // Uygulama versiyonu ekle
    // await crashlytics.setCustomKey('app_version', appVersion);
    // await crashlytics.setCustomKey('is_accessibility_app', true);
    // await crashlytics.setCustomKey('target_audience', 'visually_impaired');

    // ── Flutter Framework hataları ──
    FlutterError.onError = (FlutterErrorDetails details) {
      // Firebase:
      // crashlytics.recordFlutterFatalError(details);

      // Debug modda konsola da yaz
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }

      // Ek bağlam bilgisi
      _logErrorContext(details.exception.toString());
    };

    // ── Platform Dispatcher hataları (Dart 3+) ──
    PlatformDispatcher.instance.onError = (error, stack) {
      // Firebase:
      // crashlytics.recordError(error, stack, fatal: true);

      _logErrorContext(error.toString());
      return true;
    };

    // ── Async/Zone hataları ──
    runZonedGuarded(
      appRunner,
      (error, stackTrace) {
        // Firebase:
        // crashlytics.recordError(error, stackTrace);

        if (kDebugMode) {
          debugPrint('🔴 Yakalanmamış hata: $error');
          debugPrint('$stackTrace');
        }
        _logErrorContext(error.toString());
      },
    );

    _initialized = true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // YEREL EKRAN BAĞLAMI (uzaktan gönderilmez)
  // ─────────────────────────────────────────────────────────────────────────

  /// Aktif ekranı güncelle (hata raporlarına eklenir)
  void setCurrentScreen(String screenName) {
    _currentScreen = screenName;

    // Firebase:
    // FirebaseCrashlytics.instance.setCustomKey('current_screen', screenName);

    if (kDebugMode) {
      debugPrint('📱 Ekran: $screenName');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MANUEL HATA KAYDI
  // ─────────────────────────────────────────────────────────────────────────

  /// Kritik olmayan hatayı kaydet
  void recordError(
    dynamic error, {
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
  }) {
    if (!_initialized && !kDebugMode) return;

    // Firebase:
    // FirebaseCrashlytics.instance.recordError(
    //   error,
    //   stackTrace ?? StackTrace.current,
    //   reason: reason,
    //   fatal: fatal,
    // );

    _logErrorContext(error.toString(), reason: reason);
  }

  /// API hatası kaydet (sık karşılaşılan)
  void recordApiError({
    required String endpoint,
    required int statusCode,
    String? responseBody,
  }) {
    recordError(
      'API Hatası: $endpoint (HTTP $statusCode)',
      reason: 'api_error',
    );

    // Firebase:
    // FirebaseCrashlytics.instance.setCustomKey('last_api_error', endpoint);
    // FirebaseCrashlytics.instance.setCustomKey('last_status_code', statusCode);
  }

  /// TTS hatası kaydet
  void recordTtsError(String errorMessage) {
    recordError(
      'TTS Hatası: $errorMessage',
      reason: 'tts_error',
    );
  }

  /// Kamera hatası kaydet
  void recordCameraError(String errorMessage) {
    recordError(
      'Kamera Hatası: $errorMessage',
      reason: 'camera_error',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BREADCRUMB (İz kaydı)
  // ─────────────────────────────────────────────────────────────────────────

  /// Kullanıcı eylem breadcrumb'ı ekle (hata bağlamı için)
  void logBreadcrumb(String message, {Map<String, String>? data}) {
    // Firebase:
    // FirebaseCrashlytics.instance.log(message);

    if (kDebugMode) {
      debugPrint('🍞 Breadcrumb: $message ${data ?? ""}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BAĞLAM BİLGİSİ
  // ─────────────────────────────────────────────────────────────────────────

  void _logErrorContext(String error, {String? reason}) {
    if (kDebugMode) {
      debugPrint('═══ HATA RAPORU ═══');
      debugPrint('  Ekran: $_currentScreen');
      debugPrint('  Versiyon: $_appVersion');
      debugPrint('  Hata: $error');
      if (reason != null) debugPrint('  Sebep: $reason');
      debugPrint('═══════════════════');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NAVIGATOR OBSERVER — Otomatik ekran takibi
// ═══════════════════════════════════════════════════════════════════════════════

class CrashReporterObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    _updateScreen(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute != null) {
      _updateScreen(previousRoute);
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) {
      _updateScreen(newRoute);
    }
  }

  void _updateScreen(Route route) {
    final name = route.settings.name ?? route.runtimeType.toString();
    CrashReporter.instance.setCurrentScreen(name);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN.DART ENTEGRASYON ÖRNEĞİ
// ═══════════════════════════════════════════════════════════════════════════════

/*
/// main.dart'ta şu şekilde kullanılır:
///
/// ```dart
/// import 'core/utils/crash_reporter.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await CrashReporter.instance.initialize(
///     appVersion: '1.0.0',
///     appRunner: () => runApp(
///       MaterialApp(
///         navigatorObservers: [CrashReporterObserver()],
///         home: const HomeScreen(),
///       ),
///     ),
///   );
/// }
/// ```
*/
