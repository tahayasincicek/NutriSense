import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum OfflineRecognitionStatus { success, unavailable, rejected, error }

class OfflineRecognitionOutcome {
  final OfflineRecognitionStatus status;
  final String message;

  const OfflineRecognitionOutcome(this.status, this.message);
}

/// Offline inference remains fail-closed until a verified model, labels,
/// preprocessing contract, checksum and validation threshold are bundled.
abstract interface class OfflineFoodRecognizer {
  bool get isAvailable;
  Future<OfflineRecognitionOutcome> recognize(Uint8List rgbJpegBytes);
  Future<void> dispose();
}

class UnavailableOfflineFoodRecognizer implements OfflineFoodRecognizer {
  const UnavailableOfflineFoodRecognizer();

  @override
  bool get isAvailable => false;

  @override
  Future<OfflineRecognitionOutcome> recognize(Uint8List rgbJpegBytes) async {
    return const OfflineRecognitionOutcome(
      OfflineRecognitionStatus.unavailable,
      'Doğrulanmış çevrimdışı model yüklü değil. Manuel giriş kullanın.',
    );
  }

  @override
  Future<void> dispose() async {}
}

final offlineFoodRecognizerProvider = Provider<OfflineFoodRecognizer>((ref) {
  const recognizer = UnavailableOfflineFoodRecognizer();
  ref.onDispose(recognizer.dispose);
  return recognizer;
});
