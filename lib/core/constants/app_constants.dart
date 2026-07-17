// =============================================================================
// lib/core/constants/app_constants.dart
// NutriSense — Uygulama Genelinde Kullanılan Sabitler
// =============================================================================

import '../config/app_config.dart';

/// API ve ağ yapılandırması
class ApiConstants {
  ApiConstants._();

  static String get baseUrl => AppConfig.apiBaseUrl;
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // FastAPI OpenAPI ile kanonik endpointler. Eski `/food/recognize` yolu için
  // sessiz fallback yoktur.
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String analyzeFood = '/analyze-food';
  static const String foodHistory = '/food-history';
  static const String sendToDietitian = '/send-to-dietitian';
  static const String survey = '/survey';
  static const String usability = '/usability';
}

/// Uygulama genelinde kullanılan sabitler
class AppConstants {
  AppConstants._();

  static const String appName = 'NutriSense';
  static const String appVersion = '1.0.0';

  // Desteklenen diller
  static const String defaultLocale = 'tr-TR';
  static const List<String> supportedLocales = ['tr-TR', 'en-US'];

  // Kamera ayarları
  static const double minBlurScore = 100.0; // Laplacian variance eşiği
  static const int maxImageSizeBytes = 2 * 1024 * 1024; // 2MB
  static const int imageQuality = 85; // JPEG kalitesi (%)
  static const int cameraInputWidth = 224; // Model input boyutu
  static const int cameraInputHeight = 224;

  // Besin tanıma güvenilirlik eşikleri
  static const double highConfidenceThreshold = 0.85;
  static const double lowConfidenceThreshold = 0.60;

  // TTS ayarları
  static const double defaultTtsSpeed = 0.5; // 0.0 - 1.0 arası
  static const double defaultTtsPitch = 1.0;
  static const double defaultTtsVolume = 1.0;

  // Kalori hedefleri (varsayılanlar)
  static const double defaultDailyCalorieTarget = 2000.0;
  static const double calorieWarningThreshold = 0.9; // %90'ında uyar

  // Zaman aşımları
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration snackbarDuration = Duration(seconds: 4);
  static const Duration debounceDelay = Duration(milliseconds: 500);
}

/// SharedPreferences anahtarları
class StorageKeys {
  StorageKeys._();

  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userRole = 'user_role';
  static const String isDarkMode = 'is_dark_mode';
  static const String ttsSpeed = 'tts_speed';
  static const String ttsLanguage = 'tts_language';
  static const String fontSize = 'font_size';
  static const String highContrast = 'high_contrast';
  static const String hapticFeedback = 'haptic_feedback';
  static const String isFirstLaunch = 'is_first_launch';
  static const String dailyCalorieTarget = 'daily_calorie_target';
}

/// Sesli komut niyet türleri
class VoiceIntents {
  VoiceIntents._();

  static const String takePhoto = 'TAKE_PHOTO';
  static const String showCalories = 'SHOW_CALORIES';
  static const String logMeal = 'LOG_MEAL';
  static const String dailySummary = 'DAILY_SUMMARY';
  static const String sendReport = 'SEND_REPORT';
  static const String help = 'HELP';
  static const String goBack = 'GO_BACK';
  static const String openSettings = 'OPEN_SETTINGS';
}

/// Yemek öğünü türleri
class MealTypes {
  MealTypes._();

  static const String breakfast = 'breakfast';
  static const String lunch = 'lunch';
  static const String dinner = 'dinner';
  static const String snack = 'snack';

  static const Map<String, String> labels = {
    breakfast: 'Kahvaltı',
    lunch: 'Öğle Yemeği',
    dinner: 'Akşam Yemeği',
    snack: 'Atıştırmalık',
  };
}

/// Erişilebilirlik sabitleri
class A11yConstants {
  A11yConstants._();

  /// Minimum dokunma alanı boyutu (dp) — WCAG 2.5.5
  static const double minTouchTarget = 48.0;

  /// Minimum kontrast oranı — WCAG 1.4.3 AA
  static const double minContrastRatio = 4.5;

  /// Büyük metin minimum kontrast oranı — WCAG 1.4.3 AA
  static const double minLargeTextContrastRatio = 3.0;

  /// Odak göstergesi genişliği
  static const double focusIndicatorWidth = 3.0;

  /// Animasyon süreleri — vestibüler hassasiyet için kısa tutulur
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
}
