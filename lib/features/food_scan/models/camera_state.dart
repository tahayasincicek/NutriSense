import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/food_analysis_model.dart';

enum CameraStatus {
  permissionRequesting,
  initializing,
  ready,
  qualityWarning,
  capturing,
  preprocessing,
  uploading,
  offlineInference,
  resultReady,
  confirmationRequired,
  confirmed,
  rejected,
  corrected,
  saved,
  error,
}

class CameraState {
  final CameraStatus status;
  final String statusMessage;
  final String? errorMessage;
  final bool isFlashOn;
  final bool isAutoCapture;
  final double? brightness;
  final bool isBlurry;
  final FoodAnalysisResult? analysis;
  final String? recognizedFood;
  final double? calories;
  final double? confidence;
  final String? savedLogId;
  final bool permissionPermanentlyDenied;

  const CameraState({
    this.status = CameraStatus.permissionRequesting,
    this.statusMessage = 'Kamera izni isteniyor...',
    this.errorMessage,
    this.isFlashOn = false,
    this.isAutoCapture = true,
    this.brightness,
    this.isBlurry = false,
    this.analysis,
    this.recognizedFood,
    this.calories,
    this.confidence,
    this.savedLogId,
    this.permissionPermanentlyDenied = false,
  });

  CameraState copyWith({
    CameraStatus? status,
    String? statusMessage,
    String? errorMessage,
    bool? isFlashOn,
    bool? isAutoCapture,
    double? brightness,
    bool? isBlurry,
    FoodAnalysisResult? analysis,
    String? recognizedFood,
    double? calories,
    double? confidence,
    String? savedLogId,
    bool? permissionPermanentlyDenied,
    bool clearAnalysis = false,
  }) =>
      CameraState(
        status: status ?? this.status,
        statusMessage: statusMessage ?? this.statusMessage,
        errorMessage: errorMessage,
        isFlashOn: isFlashOn ?? this.isFlashOn,
        isAutoCapture: isAutoCapture ?? this.isAutoCapture,
        brightness: brightness ?? this.brightness,
        isBlurry: isBlurry ?? this.isBlurry,
        analysis: clearAnalysis ? null : analysis ?? this.analysis,
        recognizedFood:
            clearAnalysis ? null : recognizedFood ?? this.recognizedFood,
        calories: clearAnalysis ? null : calories ?? this.calories,
        confidence: clearAnalysis ? null : confidence ?? this.confidence,
        savedLogId: clearAnalysis ? null : savedLogId ?? this.savedLogId,
        permissionPermanentlyDenied:
            permissionPermanentlyDenied ?? this.permissionPermanentlyDenied,
      );
}

class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier() : super(const CameraState());

  void setPermissionRequesting() => state = state.copyWith(
        status: CameraStatus.permissionRequesting,
        statusMessage: 'Kamera izni isteniyor...',
      );

  void setInitializing() => state = state.copyWith(
        status: CameraStatus.initializing,
        statusMessage: 'Kamera başlatılıyor...',
      );

  void setReady() => state = state.copyWith(
        status: CameraStatus.ready,
        statusMessage: 'Besini çerçeveye yerleştirin',
      );

  void setCapturing() => state = state.copyWith(
        status: CameraStatus.capturing,
        statusMessage: 'Görüntü yakalanıyor...',
      );

  void setPreprocessing() => state = state.copyWith(
        status: CameraStatus.preprocessing,
        statusMessage: 'Görüntü hazırlanıyor...',
      );

  void setUploading() => state = state.copyWith(
        status: CameraStatus.uploading,
        statusMessage: 'Güvenli analiz yapılıyor...',
      );

  void setOfflineInference() => state = state.copyWith(
        status: CameraStatus.offlineInference,
        statusMessage: 'Çevrimdışı model deneniyor...',
      );

  void setQualityWarning(String message, double brightness, bool blurry) =>
      state = state.copyWith(
        status: CameraStatus.qualityWarning,
        statusMessage: message,
        brightness: brightness,
        isBlurry: blurry,
      );

  void setAnalysis(FoodAnalysisResult result, {required bool medium}) =>
      state = state.copyWith(
        status: medium
            ? CameraStatus.confirmationRequired
            : CameraStatus.resultReady,
        statusMessage: medium
            ? 'Sonuç kesin değil; seçim yapın'
            : 'Sonucu kontrol edip onaylayın',
        analysis: result,
        recognizedFood: result.foodNameTr,
        calories: result.totalCalories,
        confidence: result.confidence,
      );

  void setSaved(String logId, {bool corrected = false}) =>
      state = state.copyWith(
        status: CameraStatus.saved,
        statusMessage: corrected
            ? 'Düzeltilen yemek geçmişe kaydedildi'
            : 'Yemek geçmişe kaydedildi',
        savedLogId: logId,
      );

  void setDecisionAccepted({required bool corrected}) => state = state.copyWith(
        status: corrected ? CameraStatus.corrected : CameraStatus.confirmed,
        statusMessage: corrected
            ? 'Düzeltme onaylandı; kayıt tamamlanıyor'
            : 'Sonuç onaylandı; kayıt tamamlanıyor',
      );

  void setRejected() => state = state.copyWith(
        status: CameraStatus.rejected,
        statusMessage: 'Sonuç reddedildi; kayıt oluşturulmadı',
      );

  void setError(String message, {bool permanentlyDenied = false}) =>
      state = CameraState(
        status: CameraStatus.error,
        errorMessage: message,
        statusMessage: message,
        isAutoCapture: state.isAutoCapture,
        permissionPermanentlyDenied: permanentlyDenied,
      );

  void toggleFlash() => state = state.copyWith(isFlashOn: !state.isFlashOn);

  void reset() => state = CameraState(
        status: CameraStatus.ready,
        statusMessage: 'Besini çerçeveye yerleştirin',
        isFlashOn: state.isFlashOn,
        isAutoCapture: state.isAutoCapture,
      );
}

final cameraStateProvider =
    StateNotifierProvider.autoDispose<CameraNotifier, CameraState>((ref) {
  return CameraNotifier();
});
