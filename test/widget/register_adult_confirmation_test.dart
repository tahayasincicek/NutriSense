import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/auth/screens/register_screen.dart';
import 'package:nutrisense/shared/widgets/accessible_button.dart';

import '../support/platform_channel_mocks.dart';

/// Yaş sınırı hukuken belirlenene kadar hizmet yetişkinlere açıktır; beyan
/// verilmeden kayıt isteği sunucuya hiç gitmemelidir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(mockSecureStorage);

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  testWidgets('18 yaş beyanı olmadan hesap oluşturulmaz', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const RegisterScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sentetik Kullanıcı');
    await tester.enterText(fields.at(1), 'sentetik@example.com');
    await tester.enterText(fields.at(2), 'Sentetik123');
    await tester.enterText(fields.at(3), 'Sentetik123');

    final checkbox = find.byKey(const Key('register_adult_confirmation'));
    expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);

    final submit = find.byType(AccessibleButton);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();

    expect(
      find.text(
          'Hesap oluşturmak için 18 yaşından büyük olduğunuzu onaylayın.'),
      findsOneWidget,
    );

    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
