import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/auth/screens/login_screen.dart';
import 'package:nutrisense/features/food_scan/screens/camera_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS dalında gerçek giriş ekranı route ve form semantiğini korur',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: LoginScreen()),
          ),
        );
        await tester.pump();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.bySemanticsLabel('Giriş'), findsOneWidget);
        expect(
          find.bySemanticsLabel('E-posta adresi giriş alanı'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Şifre giriş alanı'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'iOS dalında gerçek kamera ekranı live region ve dokunma alternatifleri sunar',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: CameraScreen(initializeHardware: false),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CameraScreen), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.liveRegion == true,
          ),
          findsWidgets,
        );
        expect(find.bySemanticsLabel('Besin adını elle gir'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Şimdi fotoğraf çek ve analiz et'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
