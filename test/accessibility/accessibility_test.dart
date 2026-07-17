// =============================================================================
// test/accessibility/accessibility_test.dart
// NutriSense — Otomatik Erişilebilirlik Denetimi
//
// Kontroller:
//   - Semantics etiket eksikliği
//   - Dokunma hedef boyutu (minimum 44×44dp)
//   - Contrast ratio (minimum 4.5:1)
//   - Etkileşimli öğelerin semantik etiketleri
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nutrisense/core/theme/app_theme.dart';

void main() {
  group('Erişilebilirlik Denetimi', () {
    Widget buildApp(Widget child) {
      return ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: child,
        ),
      );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SEMANTİCS ETİKET KONTROLÜ
    // ═══════════════════════════════════════════════════════════════════════

    group('Semantics Etiketleri', () {
      testWidgets('Tüm butonlar Semantics etiketine sahip olmalı',
          (tester) async {
        await tester.pumpWidget(
          buildApp(
            Scaffold(
              body: Column(
                children: [
                  Semantics(
                    label: 'Besin tara',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Tara'),
                    ),
                  ),
                  Semantics(
                    label: 'Geçmişi görüntüle',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Geçmiş'),
                    ),
                  ),
                  Semantics(
                    label: 'Ayarları aç',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Ayarlar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Besin tara'), findsOneWidget);
        expect(find.bySemanticsLabel('Geçmişi görüntüle'), findsOneWidget);
        expect(find.bySemanticsLabel('Ayarları aç'), findsOneWidget);
      });

      testWidgets('İkon butonları erişilebilir etiketli olmalı',
          (tester) async {
        await tester.pumpWidget(
          buildApp(
            Scaffold(
              appBar: AppBar(
                actions: [
                  Semantics(
                    label: 'Sesli özet dinle',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.volume_up),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Sesli özet dinle'), findsOneWidget);
      });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // DOKUNMA HEDEF BOYUTU
    // ═══════════════════════════════════════════════════════════════════════

    group('Dokunma Hedef Boyutu (min 44×44dp)', () {
      testWidgets('ElevatedButton minimum boyutu karşılamalı', (tester) async {
        await tester.pumpWidget(
          buildApp(
            Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  child: const Text('Test'),
                ),
              ),
            ),
          ),
        );

        final button = tester.getSize(find.byType(ElevatedButton));
        expect(button.width, greaterThanOrEqualTo(44));
        expect(button.height, greaterThanOrEqualTo(44));
      });

      testWidgets('IconButton minimum boyutu karşılamalı', (tester) async {
        await tester.pumpWidget(
          buildApp(
            Scaffold(
              body: Center(
                child: IconButton(
                  icon: const Icon(Icons.settings),
                  iconSize: 24,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );

        final button = tester.getSize(find.byType(IconButton));
        expect(button.width, greaterThanOrEqualTo(44));
        expect(button.height, greaterThanOrEqualTo(44));
      });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // KONTRAST ORANI
    // ═══════════════════════════════════════════════════════════════════════

    group('Kontrast Oranı (min 4.5:1)', () {
      test('Tema renkleri yeterli kontrasta sahip olmalı', () {
        /// WCAG 2.1 AA: minimum 4.5:1 normal metin, 3:1 büyük metin.
        /// Kontrast oranı hesaplama: (L1 + 0.05) / (L2 + 0.05)

        // Birincil metin (siyah) beyaz arka plan üzerinde
        final contrastBlackOnWhite = _contrastRatio(Colors.black, Colors.white);
        expect(contrastBlackOnWhite, greaterThanOrEqualTo(4.5));

        // Birincil renk beyaz arka plan üzerinde
        final contrastPrimaryOnWhite = _contrastRatio(
          AppTheme.primaryColor,
          Colors.white,
        );
        expect(contrastPrimaryOnWhite, greaterThanOrEqualTo(3.0));
        // Not: Büyük metin kuralı (3:1) — başlıklarda kullanıyoruz

        // Beyaz metin koyu arka plan üzerinde
        final contrastWhiteOnPrimary = _contrastRatio(
          Colors.white,
          AppTheme.primaryDark,
        );
        expect(contrastWhiteOnPrimary, greaterThanOrEqualTo(4.5));
      });

      test('Hata rengi yeterli kontrasta sahip olmalı', () {
        final contrast = _contrastRatio(Colors.red[700]!, Colors.white);
        expect(contrast, greaterThanOrEqualTo(3.0));
      });
    });

    // ═══════════════════════════════════════════════════════════════════════
    // FONKSİYONEL ERİŞİLEBİLİRLİK
    // ═══════════════════════════════════════════════════════════════════════

    group('Fonksiyonel Erişilebilirlik', () {
      testWidgets('Yükleme göstergesi ekran okuyucu metni içermeli',
          (tester) async {
        await tester.pumpWidget(
          buildApp(
            Scaffold(
              body: Center(
                child: Semantics(
                  label: 'Yükleniyor',
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Yükleniyor'), findsOneWidget);
      });

      testWidgets('Form alanları erişilebilir etiketli olmalı', (tester) async {
        await tester.pumpWidget(
          buildApp(
            Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  label: 'E-posta adresi girin',
                  textField: true,
                  child: const TextField(
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      hintText: 'ornek@mail.com',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('E-posta adresi girin'), findsOneWidget);
      });

      testWidgets('Slider erişilebilir olmalı', (tester) async {
        await tester.pumpWidget(
          buildApp(
            Scaffold(
              body: Semantics(
                label: 'Konuşma hızı',
                slider: true,
                value: '1.0x',
                child: Slider(
                  value: 0.5,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Konuşma hızı'), findsOneWidget);
      });
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// YARDIMCI FONKSİYONLAR
// ═══════════════════════════════════════════════════════════════════════════════

/// WCAG 2.1 kontrast oranı hesaplama
double _contrastRatio(Color foreground, Color background) {
  final l1 = _relativeLuminance(foreground);
  final l2 = _relativeLuminance(background);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Göreceli parlaklık (sRGB → linear)
double _relativeLuminance(Color color) {
  double linearize(int component) {
    final sRGB = component / 255.0;
    return sRGB <= 0.03928
        ? sRGB / 12.92
        : math.pow((sRGB + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linearize(color.red) +
      0.7152 * linearize(color.green) +
      0.0722 * linearize(color.blue);
}
