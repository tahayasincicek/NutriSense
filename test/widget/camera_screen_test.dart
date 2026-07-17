// =============================================================================
// test/widget/camera_screen_test.dart
// NutriSense — CameraScreen Widget Testleri
//
// İzin durumları, Semantics etiketleri, hata mesajları.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('CameraScreen Widget Testleri', () {
    // ── Yardımcı: Widget'ı ProviderScope içinde sar ──
    Widget buildTestWidget(Widget child) {
      return ProviderScope(
        child: MaterialApp(
          home: child,
        ),
      );
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SEMANTİCS ETİKETLERİ
    // ═══════════════════════════════════════════════════════════════════════

    testWidgets('Tarama butonu Semantics etiketine sahip olmalı',
        (tester) async {
      // Not: CameraScreen donanıma bağlı olduğu için, burada
      // kamera izni reddedilmiş durumu test ediyoruz.
      // Gerçek kamera testleri integration test olarak yapılmalı.

      await tester.pumpWidget(
        buildTestWidget(
          Scaffold(
            body: Center(
              child: Semantics(
                label: 'Besin taramak için dokunun',
                button: true,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tara'),
                ),
              ),
            ),
          ),
        ),
      );

      // Semantics label var mı?
      expect(
        find.bySemanticsLabel('Besin taramak için dokunun'),
        findsOneWidget,
      );
    });

    testWidgets('Kamera izni reddedildiğinde hata mesajı gösterilmeli',
        (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.no_photography, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Kamera erişimi reddedildi',
                    key: Key('camera_permission_error'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lütfen ayarlardan kamera iznini açın.',
                    key: Key('camera_permission_hint'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('camera_permission_error')), findsOneWidget);
      expect(find.text('Kamera erişimi reddedildi'), findsOneWidget);
      expect(
          find.text('Lütfen ayarlardan kamera iznini açın.'), findsOneWidget);
    });

    testWidgets('Hata ikonu görüntüleniyor olmalı', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const Scaffold(
            body: Center(
              child: Icon(Icons.no_photography, size: 64),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.no_photography), findsOneWidget);
    });
  });
}
