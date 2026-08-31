import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/auth/screens/login_screen.dart';
import 'package:nutrisense/features/auth/screens/password_reset_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  Widget app(Widget home) => ProviderScope(
        child: MaterialApp(theme: AppTheme.lightTheme, home: home),
      );

  group('Parola sıfırlama', () {
    testWidgets('giriş ekranındaki buton sıfırlama ekranını açar',
        (tester) async {
      await tester.pumpWidget(app(const LoginScreen()));
      await tester.pump();

      final button = find.byKey(const Key('forgot_password'));
      expect(button, findsOneWidget);

      // Buton artık ölü değil: gerçek bir eylemi olmalı.
      final widget = tester.widget<TextButton>(button);
      expect(widget.onPressed, isNotNull);

      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(PasswordResetScreen), findsOneWidget);
    });

    testWidgets('ilk adımda e-posta alanı gösterilir', (tester) async {
      await tester.pumpWidget(app(const PasswordResetScreen()));
      await tester.pump();

      expect(find.byKey(const Key('reset_email')), findsOneWidget);
      // Kod alanı henüz görünmemeli.
      expect(find.byKey(const Key('reset_code')), findsNothing);
      expect(find.text('Kod Gönder'), findsOneWidget);
    });

    testWidgets('geçersiz e-posta reddedilir ve adım ilerlemez',
        (tester) async {
      await tester.pumpWidget(app(const PasswordResetScreen()));
      await tester.pump();

      await tester.enterText(
          find.byKey(const Key('reset_email')), 'gecersiz');
      await tester.tap(find.byKey(const Key('reset_primary_action')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Geçerli bir e-posta'), findsOneWidget);
      expect(find.byKey(const Key('reset_code')), findsNothing);
    });

    testWidgets('e-posta önceden doldurulabilir', (tester) async {
      await tester.pumpWidget(
        app(const PasswordResetScreen(initialEmail: 'taha@example.com')),
      );
      await tester.pump();

      final field =
          tester.widget<TextField>(find.byKey(const Key('reset_email')));
      expect(field.controller!.text, 'taha@example.com');
    });

    testWidgets('form alanları ekran okuyucu etiketi taşır', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const PasswordResetScreen()));
      await tester.pump();

      expect(
        find.bySemanticsLabel('E-posta adresi giriş alanı'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('yüzde 200 fontta taşma üretmez', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const PasswordResetScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
