// =============================================================================
// lib/shared/services/navigation_announcer.dart
// NutriSense — Bağlam Duyarlı Ekran Okuma Servisi
//
// Kullanıcı hangi ekrana geçerse, o ekranın ne içerdiğini otomatik okur.
// Route değişikliklerini dinler ve TTS ile duyurur.
//
// Lifecycle:
//   1. Ekran gösterildiğinde → kısa gecikmeyle ekranı announce et
//   2. Sonuç geldiğinde → sonucu announce et
//   3. Hata oluştuğunda → hatayı CRITICAL öncelikle announce et
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import 'accessibility_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// EKRAN TANIMLARI
// ═══════════════════════════════════════════════════════════════════════════════

/// Uygulama ekranları
enum AppScreen {
  login(AppStrings.screenLogin),
  scan(AppStrings.screenScan),
  camera(AppStrings.cameraReady),
  history(AppStrings.screenHistory),
  dietitian(AppStrings.screenDietitian),
  settings(AppStrings.screenSettings);

  const AppScreen(this.announcement);
  final String announcement;
}

// ═══════════════════════════════════════════════════════════════════════════════
// NAVİGASYON DUYURUCU
// ═══════════════════════════════════════════════════════════════════════════════

class NavigationAnnouncer {
  final AccessibilityService _accessibility;

  // ── Durum ──
  AppScreen? _currentScreen;
  Timer? _announceTimer;
  bool _firstLaunch = true;

  NavigationAnnouncer({required AccessibilityService accessibility})
      : _accessibility = accessibility;

  AppScreen? get currentScreen => _currentScreen;

  // ─────────────────────────────────────────────────────────────────────────
  // EKRAN GEÇİŞLERİ
  // ─────────────────────────────────────────────────────────────────────────

  /// Yeni ekrana geçişte çağrılır — ekranı otomatik duyurur.
  ///
  /// [delay] ile kullanıcının animasyonu hissetmesi beklenir.
  void announceScreen(AppScreen screen) {
    if (_currentScreen == screen) return; // Zaten bu ekrandayız

    _currentScreen = screen;

    // Gecikmeyle duyur (ekran geçiş animasyonu tamamlansın)
    _announceTimer?.cancel();
    _announceTimer = Timer(
      Duration(milliseconds: (_accessibility.autoReadDelay * 1000).toInt()),
      () => _performAnnouncement(screen),
    );
  }

  void _performAnnouncement(AppScreen screen) {
    // İlk açılışta karşılama mesajı
    if (_firstLaunch && screen == AppScreen.scan) {
      _firstLaunch = false;
      _accessibility.speak(
        AppStrings.welcome,
        priority: TtsPriority.high,
      );
      _accessibility.successHaptic();
      return;
    }

    _accessibility.speak(
      screen.announcement,
      priority: TtsPriority.normal,
    );
    _accessibility.lightHaptic();
  }

  /// İlk açılış bayrağını resetler (tekrar karşılama için)
  void resetFirstLaunch() {
    _firstLaunch = true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BAĞLAM DUYARLI DUYURULAR
  // ─────────────────────────────────────────────────────────────────────────

  /// Kamera ekranı aktif olduğunda
  void announceCameraReady() {
    _accessibility.speak(
      AppStrings.cameraReady,
      priority: TtsPriority.normal,
    );
  }

  /// Tarama başladığında
  void announceScanStarted() {
    _accessibility.speak(
      AppStrings.scanStarting,
      priority: TtsPriority.high,
    );
    _accessibility.mediumHaptic();
  }

  /// Analiz devam ediyor
  void announceScanProcessing() {
    _accessibility.speak(
      AppStrings.scanInProgress,
      priority: TtsPriority.normal,
    );
  }

  /// Besin tanındı — sonucu duyur
  void announceFoodRecognized({
    required String foodName,
    required double calories,
    required double portionG,
    required double protein,
    required double carb,
    required double fat,
    required double confidence,
  }) {
    final confidencePercent = (confidence * 100).toInt();

    String message;
    if (confidence >= 0.85) {
      message = AppStrings.foodRecognizedDetailed(
        foodName: foodName,
        calories: calories,
        portionG: portionG,
        protein: protein,
        carb: carb,
        fat: fat,
      );
    } else if (confidence >= 0.6) {
      message = AppStrings.lowConfidence(foodName, confidencePercent);
    } else {
      message = AppStrings.scanNoFood;
    }

    _accessibility.speak(message, priority: TtsPriority.high);
    _accessibility.doubleHaptic();
  }

  /// Kaydetme onayı sor
  void announceConfirmSave(String foodName) {
    _accessibility.speak(
      AppStrings.confirmSave(foodName),
      priority: TtsPriority.high,
    );
  }

  /// Kayıt başarılı
  void announceSaveSuccess() {
    _accessibility.speak(
      AppStrings.savedSuccessfully,
      priority: TtsPriority.normal,
    );
    _accessibility.successHaptic();
  }

  /// Kayıt iptal
  void announceSaveCancelled() {
    _accessibility.speak(
      AppStrings.saveCancelled,
      priority: TtsPriority.normal,
    );
  }

  /// Günlük özet
  void announceDailySummary({
    required double totalCalories,
    required double targetCalories,
    required int mealCount,
  }) {
    if (mealCount == 0) {
      _accessibility.speak(
        AppStrings.noFoodToday,
        priority: TtsPriority.normal,
      );
    } else {
      _accessibility.speak(
        AppStrings.dailySummary(
          totalCalories: totalCalories,
          targetCalories: targetCalories,
          mealCount: mealCount,
        ),
        priority: TtsPriority.normal,
      );
    }
  }

  /// Diyetisyene rapor gönderildi
  void announceDietitianReportSent(String dietitianName) {
    _accessibility.speak(
      AppStrings.dietitianReportSent(dietitianName),
      priority: TtsPriority.high,
    );
    _accessibility.successHaptic();
  }

  /// Kalite uyarısı (karanlık, bulanık, vb.)
  void announceQualityWarning(String warning) {
    _accessibility.speak(
      warning,
      priority: TtsPriority.high,
    );
  }

  /// Hata duyurusu — CRITICAL öncelik
  void announceError(String error) {
    _accessibility.speak(
      error,
      priority: TtsPriority.critical,
    );
    _accessibility.errorHaptic();
  }

  /// Tab değişikliği duyurusu
  void announceTabChange(int index) {
    final messages = [
      AppStrings.tabScan,
      AppStrings.tabHistory,
      AppStrings.tabDietitian,
      AppStrings.tabSettings,
    ];

    if (index >= 0 && index < messages.length) {
      _accessibility.speak(
        messages[index],
        priority: TtsPriority.normal,
      );
      _accessibility.lightHaptic();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROUTE OBSERVER (OPSİYONEL)
  // ─────────────────────────────────────────────────────────────────────────

  /// Navigator route değişikliklerini dinleyen observer
  NavigatorObserver get routeObserver => _NutriSenseRouteObserver(this);

  // ─────────────────────────────────────────────────────────────────────────
  // TEMİZLİK
  // ─────────────────────────────────────────────────────────────────────────

  void dispose() {
    _announceTimer?.cancel();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROUTE OBSERVER
// ═══════════════════════════════════════════════════════════════════════════════

class _NutriSenseRouteObserver extends NavigatorObserver {
  final NavigationAnnouncer _announcer;

  _NutriSenseRouteObserver(this._announcer);

  @override
  void didPush(Route route, Route? previousRoute) {
    _announceRoute(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute != null) {
      _announceRoute(previousRoute);
    }
  }

  void _announceRoute(Route route) {
    final name = route.settings.name;
    if (name == null) return;

    // Route isimlerini ekranlara eşle
    final screenMap = <String, AppScreen>{
      '/': AppScreen.scan,
      '/scan': AppScreen.scan,
      '/camera': AppScreen.camera,
      '/history': AppScreen.history,
      '/dietitian': AppScreen.dietitian,
      '/settings': AppScreen.settings,
      '/login': AppScreen.login,
    };

    final screen = screenMap[name];
    if (screen != null) {
      _announcer.announceScreen(screen);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RIVERPOD PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

final navigationAnnouncerProvider = Provider<NavigationAnnouncer>((ref) {
  final accessibility = ref.read(accessibilityServiceProvider);
  final announcer = NavigationAnnouncer(accessibility: accessibility);
  ref.onDispose(() => announcer.dispose());
  return announcer;
});
