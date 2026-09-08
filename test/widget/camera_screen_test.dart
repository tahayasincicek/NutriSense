import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nutrisense/features/food_scan/screens/camera_screen.dart';
import 'package:nutrisense/features/food_scan/models/camera_state.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildRealCamera({double textScale = 1, ImagePicker? picker}) {
    return ProviderScope(
      overrides: [
        accessibilityServiceProvider.overrideWithValue(_Silent()),
        if (picker != null)
          galleryImagePickerProvider.overrideWithValue(picker),
      ],
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
    expect(find.bySemanticsLabel('Galeriden besin fotoğrafı seç ve analiz et'),
        findsOneWidget);
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

  testWidgets(
      'kamera olmadan galeri açılır ve iptalden sonra tekrar seçilebilir',
      (tester) async {
    final picker = _GalleryPicker();
    await tester.pumpWidget(buildRealCamera(picker: picker));
    ProviderScope.containerOf(tester.element(find.byType(CameraScreen)))
        .read(cameraStateProvider.notifier)
        .setError('Kamera izni verilmedi.');
    await tester.pump();
    await tester.ensureVisible(find.text('Galeriden fotoğraf seç'));
    await tester.tap(find.text('Galeriden fotoğraf seç'));
    await tester.pump();
    expect(picker.calls, 1);
    expect(picker.source, ImageSource.gallery);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    picker.selection.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    picker.selection = Completer<XFile?>();
    await tester.tap(find.text('Galeriden fotoğraf seç'));
    await tester.pump();
    expect(picker.calls, 2);
    picker.selection.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _GalleryPicker extends ImagePicker {
  Completer<XFile?> selection = Completer<XFile?>();
  int calls = 0;
  ImageSource? source;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    calls++;
    this.source = source;
    return selection.future;
  }
}

class _Silent extends AccessibilityService {
  @override
  Future<void> speak(String text,
      {TtsPriority priority = TtsPriority.normal,
      bool allowWhileScreenReaderActive = false}) async {}
}
