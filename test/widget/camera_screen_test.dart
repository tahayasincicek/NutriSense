import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/food_scan/screens/camera_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildRealCamera({double textScale = 1}) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const CameraScreen(initializeHardware: false),
        ),
      ),
    );
  }

  testWidgets(
      'gerçek CameraScreen dokunmatik alternatifleri ve route kontrollerini sunar',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildRealCamera());
    await tester.pump();

    expect(find.byType(CameraScreen), findsOneWidget);
    expect(find.byTooltip('Geri'), findsOneWidget);
    expect(find.bySemanticsLabel('Besin adını elle gir'), findsOneWidget);
    expect(find.bySemanticsLabel('Şimdi fotoğraf çek ve analiz et'),
        findsOneWidget);

    for (final element in find.byType(IconButton).evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    semantics.dispose();
  });

  testWidgets('gerçek CameraScreen yüzde 200 metin ve yatay yönde taşmaz',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildRealCamera(textScale: 2));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CameraScreen), findsOneWidget);
  });
}
