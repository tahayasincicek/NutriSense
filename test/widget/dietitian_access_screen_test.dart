import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/dietitian/screens/dietitian_access_screen.dart';

void main() {
  testWidgets('diyetisyen girişinde parola yenileme yolu bulunur',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DietitianAccessScreen()),
      ),
    );

    expect(find.byKey(const Key('dietitian_forgot_password')), findsOneWidget);
    expect(find.text('Şifremi Unuttum'), findsOneWidget);
    expect(find.text('PRO'), findsNothing);
  });
}
