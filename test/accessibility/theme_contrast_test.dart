import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/core/theme/theme_controller.dart';

/// Az gören kullanıcıların bir kısmı koyu zeminde okur; karanlık tema da
/// aydınlık tema kadar okunaklı olmalı. WCAG AA gövde metni eşiği 4.5:1.
///
/// Tema `google_fonts` kullandığı ve yazı tipi testte indirilemediği için
/// ThemeData kurmak yerine renk sabitleri doğrudan ölçülür; kontrast zaten
/// yalnızca renklere bağlıdır.
double _relativeLuminance(Color color) {
  double linearize(double component) {
    final value = component / 255;
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linearize(color.r * 255) +
      0.7152 * linearize(color.g * 255) +
      0.0722 * linearize(color.b * 255);
}

double _contrast(Color foreground, Color background) {
  final first = _relativeLuminance(foreground);
  final second = _relativeLuminance(background);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ThemeController tercihleri SharedPreferences'tan okur.
  final store = <String, Object>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async => switch (call.method) {
      'getAll' => store,
      'setString' => true,
      _ => null,
    },
  );

  group('Aydınlık tema kontrastı', () {
    test('gövde metni yüzey üzerinde okunur', () {
      expect(
        _contrast(AppTheme.lightOnSurface, AppTheme.lightSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('ikincil metin yüzey üzerinde okunur', () {
      expect(
        _contrast(AppTheme.lightOnSurfaceMuted, AppTheme.lightSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('buton dolgusu üzerindeki beyaz metin okunur', () {
      // ElevatedButton her iki temada da primaryDark dolgu + beyaz metin.
      expect(
        _contrast(Colors.white, AppTheme.primaryDark),
        greaterThanOrEqualTo(4.5),
        reason: 'Buton yazısı okunmuyor',
      );
    });
  });

  group('Karanlık tema kontrastı', () {
    test('gövde metni yüzey üzerinde okunur', () {
      expect(
        _contrast(AppTheme.darkOnSurface, AppTheme.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('ikincil metin yüzey üzerinde okunur', () {
      expect(
        _contrast(AppTheme.darkOnSurfaceMuted, AppTheme.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('vurgu rengi koyu yüzeyde okunur', () {
      // Koyu temada primary parlak tondur; metin/ikon rengi olarak kullanılır.
      expect(
        _contrast(AppTheme.primaryColor, AppTheme.darkSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'Koyu temada vurgu rengi okunmuyor',
      );
    });
  });

  group('Tema tercihi', () {
    test('varsayılan olarak cihaz ayarını izler', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeControllerProvider), ThemeMode.system);
    });

    test('karanlık mod açılıp kapatılabilir', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(themeControllerProvider.notifier);

      await controller.setDark(true);
      expect(container.read(themeControllerProvider), ThemeMode.dark);

      await controller.setDark(false);
      expect(container.read(themeControllerProvider), ThemeMode.light);
    });

    test('sistem modunda cihaz parlaklığına göre durum bildirir', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(themeControllerProvider.notifier);

      expect(controller.isDark(Brightness.dark), isTrue);
      expect(controller.isDark(Brightness.light), isFalse);
    });
  });
}
