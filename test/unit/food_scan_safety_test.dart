import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nutrisense/features/food_scan/models/camera_state.dart';
import 'package:nutrisense/features/food_scan/services/image_preprocessing.dart';
import 'package:nutrisense/features/food_scan/services/offline_recognizer.dart';
import 'package:nutrisense/features/food_scan/services/recognition_policy.dart';
import 'package:nutrisense/shared/models/food_analysis_model.dart';

Map<String, dynamic> fixture(String name) => jsonDecode(
      File('contracts/fixtures/$name').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  group('kamera state machine', () {
    test('izin kalıcı reddinde ayarlar kapısını işaretler', () {
      final notifier = CameraNotifier();
      notifier.setPermissionRequesting();
      notifier.setError('İzin kapalı', permanentlyDenied: true);
      expect(notifier.state.status, CameraStatus.error);
      expect(notifier.state.permissionPermanentlyDenied, isTrue);
    });

    test('yalnız server kaydı sonrası saved durumuna geçer', () {
      final notifier = CameraNotifier();
      final result = FoodAnalysisResult.fromJson(
        fixture('food_analysis_success.json'),
      );
      notifier.setAnalysis(result, medium: false);
      expect(notifier.state.status, CameraStatus.resultReady);
      expect(notifier.state.savedLogId, isNull);
      notifier.setDecisionAccepted(corrected: false);
      expect(notifier.state.status, CameraStatus.confirmed);
      notifier.setSaved('9b661f6e-744f-40f2-9c47-9849349099d5');
      expect(notifier.state.status, CameraStatus.saved);
    });
  });

  group('güvenli sonuç politikası', () {
    const policy = RecognitionPolicy();

    test('yüksek güveni yine kullanıcı onayına bırakır', () {
      final result = FoodAnalysisResult.fromJson(
        fixture('food_analysis_success.json'),
      );
      expect(policy.classify(result), RecognitionBand.high);
      expect(result.needsConfirmation, isTrue);
    });

    test('kalorisi sıfır ve OOD-benzeri yanıtı düşük güvene indirir', () {
      final result = FoodAnalysisResult.fromJson(
        fixture('food_analysis_low_confidence.json'),
      );
      expect(policy.classify(result), RecognitionBand.low);
      expect(result.canConfirm, isFalse);
    });
  });

  group('görüntü kalite ve preprocessing', () {
    test('karanlık fixture reddedilir', () async {
      final image = img.Image(width: 320, height: 240)
        ..clear(img.ColorRgb8(2, 2, 2));
      final quality = await ImagePreprocessor.checkQuality(
        Uint8List.fromList(img.encodeJpg(image)),
      );
      expect(quality.isTooDark, isTrue);
      expect(quality.isAcceptable, isFalse);
    });

    test('keskin fixture merkezden 224 kare JPEG üretir', () async {
      final image = img.Image(width: 400, height: 300);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final light = ((x ~/ 8) + (y ~/ 8)).isEven;
          image.setPixel(x, y,
              light ? img.ColorRgb8(230, 230, 230) : img.ColorRgb8(25, 25, 25));
        }
      }
      final result = await ImagePreprocessor.processImage(
        imageBytes: Uint8List.fromList(img.encodeJpg(image)),
      );
      final decoded = img.decodeJpg(result.processedBytes);
      expect(result.isAcceptableQuality, isTrue);
      expect(decoded?.width, 224);
      expect(decoded?.height, 224);
    });
  });

  test('model yokken offline yol sahte başarı üretmez', () async {
    const recognizer = UnavailableOfflineFoodRecognizer();
    final result = await recognizer.recognize(Uint8List(0));
    expect(result.status, OfflineRecognitionStatus.unavailable);
    expect(result.status, isNot(OfflineRecognitionStatus.success));
  });
}
