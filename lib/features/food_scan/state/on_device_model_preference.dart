import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnDeviceModelKey = 'use_on_device_model';

/// Taramayı sunucu yerine cihaz üstü modelle yapma tercihi.
///
/// Varsayılan kapalıdır: sunucu tarafı besin değerini doğrulanmış kaynaktan
/// verir, cihaz üstü model yalnız sınıf önerir. Bağlantı koptuğunda cihaz
/// üstü model bu tercihten bağımsız olarak yine devreye girer.
class OnDeviceModelController extends StateNotifier<bool> {
  OnDeviceModelController() : super(false) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_kOnDeviceModelKey) ?? false;
    } catch (_) {
      // Depolama okunamazsa varsayılan davranış sürer.
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnDeviceModelKey, value);
    } catch (_) {
      // Tercih bu oturum için geçerli kalır.
    }
  }
}

final onDeviceModelProvider =
    StateNotifierProvider<OnDeviceModelController, bool>(
  (ref) => OnDeviceModelController(),
);
