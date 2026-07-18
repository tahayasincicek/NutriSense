import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/auth/screens/login_screen.dart';
import 'package:nutrisense/shared/widgets/accessible_button.dart';

void main() {
  Widget app({double textScale = 1}) => ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      );

  testWidgets('gerçek LoginScreen route, başlık, alan ve eylem semantiği taşır',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Giriş'), findsOneWidget);
    expect(find.bySemanticsLabel('E-posta adresi giriş alanı'), findsOneWidget);
    expect(find.bySemanticsLabel('Şifre giriş alanı'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Hesabınıza giriş yapmak için basın'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Yeni bir hesap oluşturmak için basın'),
      findsOneWidget,
    );

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    final fieldWidgets = fields.evaluate().toList();
    expect(
      tester.getTopLeft(find.byWidget(fieldWidgets[0].widget)).dy,
      lessThan(tester.getTopLeft(find.byWidget(fieldWidgets[1].widget)).dy),
    );
    semantics.dispose();
  });

  testWidgets('gerçek LoginScreen yüzde 200 metinde taşmaz ve hedefler 48dp',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(app(textScale: 2));
    await tester.pump();

    expect(tester.takeException(), isNull);
    for (final element in find.byType(AccessibleButton).evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
