import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kShakeEnabledKey = 'shake_to_listen_enabled';

/// Sallayarak sesli komut başlatma tercihi.
///
/// Varsayılan açıktır: uygulamanın hedef kullanıcısı ekranda düğme aramadan
/// komut verebilmelidir. Yanlış tetiklemeden rahatsız olan kullanıcı
/// Erişilebilirlik ayarlarından kapatabilir.
class ShakeToListenController extends StateNotifier<bool> {
  ShakeToListenController() : super(true) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_kShakeEnabledKey) ?? true;
    } catch (_) {
      // Depolama okunamazsa varsayılan davranış sürer.
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kShakeEnabledKey, value);
    } catch (_) {
      // Tercih bu oturum için geçerli kalır.
    }
  }
}

final shakeToListenProvider =
    StateNotifierProvider<ShakeToListenController, bool>(
  (ref) => ShakeToListenController(),
);
