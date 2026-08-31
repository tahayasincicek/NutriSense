// =============================================================================
// lib/core/theme/theme_controller.dart
// NutriSense — Tema tercihi
//
// Karanlık mod tercihi cihazda saklanır; uygulama yeniden açıldığında da
// korunur. Az gören kullanıcıların bir kısmı koyu zeminde açık metni daha
// rahat okur, bu yüzden tercih kalıcı olmalıdır.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app_theme_mode';

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system) {
    _restore();
  }

  /// Kullanıcı, kayıtlı tercih okunmadan önce seçim yapmış olabilir; bu
  /// durumda geri yükleme onu ezmemeli.
  bool _userChanged = false;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userChanged || !mounted) return;
    final stored = prefs.getString(_themeModeKey);
    state = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    _userChanged = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  /// Ayarlar ekranındaki iki durumlu anahtar için.
  Future<void> setDark(bool enabled) =>
      setMode(enabled ? ThemeMode.dark : ThemeMode.light);

  /// Anahtarın gösterilecek durumu. Sistem modundayken cihazın o anki
  /// ayarına göre karar verilir.
  bool isDark(Brightness platformBrightness) => switch (state) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system => platformBrightness == Brightness.dark,
      };
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeMode>(
  (ref) => ThemeController(),
);
