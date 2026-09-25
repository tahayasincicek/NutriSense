import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/auth/screens/register_screen.dart';
import 'package:nutrisense/shared/widgets/accessible_button.dart';

import '../support/platform_channel_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(mockSecureStorage);

  testWidgets('kayıt koşulları okunabilir ve onay verilmeden kayıt açılamaz',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegisterScreen())),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(AccessibleButton, 'Hesap Oluştur');
    expect(tester.widget<AccessibleButton>(submit).onPressed, isNull);

    final information = find.byKey(const Key('registration_information_link'));
    await tester.ensureVisible(information);
    await tester.tap(information);
    await tester.pumpAndSettle();
    expect(find.text('Kullanım Koşulları'), findsOneWidget);
    expect(find.text('Aydınlatma Metni'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final acceptance = find.byKey(const Key('registration_terms_acceptance'));
    await tester.ensureVisible(acceptance);
    await tester.tap(acceptance);
    await tester.pumpAndSettle();
    expect(tester.widget<AccessibleButton>(submit).onPressed, isNotNull);
  });
}
