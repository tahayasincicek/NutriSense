// =============================================================================
// lib/features/food_scan/models/camera_state.dart
// NutriSense — Kamera Durum Yönetimi
//
// CameraState enum'u ve CameraNotifier — Riverpod ile durum yönetimi.
// Her durum geçişinde TTS ile sesli bildirim yapılır.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kamera durumları — her geçişte TTS ile bildirilir
enum CameraStatus {
  /// Kamera başlatılıyor
  initializing,

  /// Kamera hazır, tarama bekliyor
  ready,

  /// Otomatik kare yakalama aktif
  capturing,

  /// Yakalanan görüntü işleniyor / backend'e gönderiliyor
  processing,

  /// Yiyecek tespit edildi, sonuç bekleniyor
  foodDetected,

  /// Sonuç alındı
  resultReady,

  /// Hata durumu
  error,
}

/// Kamera durum modeli — tüm UI state'i tek yerde
class CameraState {
  final CameraStatus status;
  final String? statusMessage;
  final String? errorMessage;
  final bool isFlashOn;
  final bool isAutoCapture;
  final double? brightness;
  final bool isBlurry;
  final String? recognizedFood;
  final double? calories;
  final double? confidence;

  const CameraState({
    this.status = CameraStatus.initializing,
    this.statusMessage,
    this.errorMessage,
    this.isFlashOn = false,
    this.isAutoCapture = true,
    this.brightness,
    this.isBlurry = false,
    this.recognizedFood,
    this.calories,
    this.confidence,
  });

  CameraState copyWith({
    CameraStatus? status,
    String? statusMessage,
    String? errorMessage,
    bool? isFlashOn,
    bool? isAutoCapture,
    double? brightness,
    bool? isBlurry,
    String? recognizedFood,
    double? calories,
    double? confidence,
  }) {
    return CameraState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      isAutoCapture: isAutoCapture ?? this.isAutoCapture,
      brightness: brightness ?? this.brightness,
      isBlurry: isBlurry ?? this.isBlurry,
      recognizedFood: recognizedFood,
      calories: calories,
      confidence: confidence,
    );
  }

  /// Her durum için TTS ile okunacak Türkçe mesaj
  String get ttsMessage {
    switch (status) {
      case CameraStatus.initializing:
        return 'Kamera başlatılıyor, lütfen bekleyin.';
      case CameraStatus.ready:
        return 'Kamera hazır. Besini kameraya tutun veya tara butonuna basın.';
      case CameraStatus.capturing:
        return 'Görüntü yakalanıyor, telefonu sabit tutun.';
      case CameraStatus.processing:
        return 'Yiyecek analiz ediliyor, lütfen bekleyin.';
      case CameraStatus.foodDetected:
        return 'Yiyecek tespit edildi, analiz ediliyor.';
      case CameraStatus.resultReady:
        if (recognizedFood != null && calories != null) {
          return '$recognizedFood tanındı. ${calories!.toStringAsFixed(0)} kalori.';
        }
        return 'Sonuç hazır.';
      case CameraStatus.error:
        return errorMessage ?? 'Bir hata oluştu.';
    }
  }
}

/// Kamera durum yöneticisi (Riverpod StateNotifier)
class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState());

  void setInitializing() {
    state = state.copyWith(
      status: CameraStatus.initializing,
      statusMessage: 'Kamera başlatılıyor...',
    );
  }

  void setReady() {
    state = state.copyWith(
      status: CameraStatus.ready,
      statusMessage: 'Besini kameraya tutun',
    );
  }

  void setCapturing() {
    state = state.copyWith(
      status: CameraStatus.capturing,
      statusMessage: 'Görüntü yakalanıyor...',
    );
  }

  void setProcessing() {
    state = state.copyWith(
      status: CameraStatus.processing,
      statusMessage: 'Analiz ediliyor...',
    );
  }

  void setFoodDetected() {
    state = state.copyWith(
      status: CameraStatus.foodDetected,
      statusMessage: 'Yiyecek tespit edildi!',
    );
  }

  void setResult({
    required String foodName,
    required double calories,
    required double confidence,
  }) {
    state = state.copyWith(
      status: CameraStatus.resultReady,
      statusMessage: '$foodName — ${calories.toStringAsFixed(0)} kcal',
      recognizedFood: foodName,
      calories: calories,
      confidence: confidence,
    );
  }

  void setError(String message) {
    state = CameraState(
      status: CameraStatus.error,
      errorMessage: message,
      statusMessage: message,
      isAutoCapture: state.isAutoCapture,
    );
  }

  void toggleFlash() {
    state = state.copyWith(isFlashOn: !state.isFlashOn);
  }

  void toggleAutoCapture() {
    state = state.copyWith(isAutoCapture: !state.isAutoCapture);
  }

  void updateBrightness(double brightness) {
    state = state.copyWith(brightness: brightness);
  }

  void updateBlurry(bool isBlurry) {
    state = state.copyWith(isBlurry: isBlurry);
  }

  void reset() {
    state = const CameraState(status: CameraStatus.ready);
  }
}

// =============================================================================
// RIVERPOD PROVIDERS
// =============================================================================

final cameraStateProvider =
    StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  return CameraNotifier();
});
