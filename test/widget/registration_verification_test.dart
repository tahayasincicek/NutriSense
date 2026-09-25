import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/auth/screens/registration_verification_screen.dart';

import '../support/platform_channel_stubs.dart';

/// Hesap e-postaya gelen kodla açılır; kod eksikse istek gönderilmez ve
/// yeniden gönderme aynı kayıt bilgileriyle yapılır.
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

  Future<void> pumpScreen(
      WidgetTester tester, Future<String?> Function() onResend) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [memoryTokenStoreOverride()],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: RegistrationVerificationScreen(
          email: 'sentetik@example.com',
          onResend: onResend,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('eksik kodla hesap açma denenmez', (tester) async {
    await pumpScreen(tester, () async => null);

    expect(find.textContaining('sentetik@example.com'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('verification_code')), '1234');
    await tester.tap(find.byKey(const Key('verification_confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('verification_error')), findsOneWidget);
    expect(find.text('Sekiz haneli kodu girin.'), findsOneWidget);
    await cleanUp(tester);
  });

  testWidgets('kod alanı yalnız rakam kabul eder', (tester) async {
    await pumpScreen(tester, () async => null);

    await tester.enterText(
        find.byKey(const Key('verification_code')), '12ab34');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('verification_code')))
          .controller!
          .text,
      '1234',
    );
    await cleanUp(tester);
  });

  testWidgets('kod yeniden gönderilir ve kullanıcıya bildirilir',
      (tester) async {
    var resent = 0;
    await pumpScreen(tester, () async {
      resent++;
      return null;
    });

    await tester.tap(find.byKey(const Key('verification_resend')));
    await tester.pumpAndSettle();

    expect(resent, 1);
    expect(find.byKey(const Key('verification_info')), findsOneWidget);
    await cleanUp(tester);
  });
}
