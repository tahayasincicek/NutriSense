import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// Adım sensörünü platform paketinden ayırır; durum katmanı sahte bir kaynakla
/// test edilebilir ve sensörü olmayan cihazlarda güvenli biçimde kapanabilir.
abstract interface class StepCounterSource {
  Future<bool> requestPermission();
  Stream<int> get stepCountStream;
}

class DeviceStepCounterSource implements StepCounterSource {
  const DeviceStepCounterSource();

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted || status.isLimited;
  }

  @override
  Stream<int> get stepCountStream =>
      Pedometer.stepCountStream.map((event) => event.steps);
}
