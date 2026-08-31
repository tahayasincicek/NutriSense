import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/main.dart';

void main() {
  testWidgets('NutriSense uygulama kabuğu açılır', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NutriSenseApp(
          initializePlatformServices: false,
          bypassAuthenticationForTests: true,
        ),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'NutriSense');
    // Material 3 NavigationBar; sekmeler: Tara, Aktivite, Günlük, Keşfet,
    // Diyetisyen. (Ayarlar artık sekme değil, başlıktaki ikondan açılıyor.)
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Tara'), findsOneWidget);
    expect(find.text('Aktivite'), findsOneWidget);
    expect(find.text('Günlük'), findsOneWidget);
    expect(find.text('Keşfet'), findsOneWidget);
    expect(find.text('Diyetisyen'), findsOneWidget);
  });
}
