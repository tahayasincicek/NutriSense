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
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Tara'), findsOneWidget);
    expect(find.text('Geçmiş'), findsOneWidget);
    expect(find.text('Diyetisyen'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
  });
}
