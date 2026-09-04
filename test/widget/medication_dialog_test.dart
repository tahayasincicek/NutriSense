import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/water_tracker/screens/water_tracker_screen.dart';

import '../support/platform_channel_mocks.dart';

/// Takviye ekleme diyaloğu kapanırken uygulama çökmemelidir.
///
/// Denetleyiciler `showDialog` döner dönmez kapatıldığında, kapanma animasyonu
/// sürerken ekranda duran metin alanları silinmiş denetleyiciye bakıyor ve
/// çerçeve "_dependents.isEmpty" doğrulamasıyla düşüyordu.
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

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ActivityTrackerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Takviye ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Takviye ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Takviye ekle'), findsWidgets);
  }

  testWidgets('takviye eklenince diyalog sorunsuz kapanır', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField).first, 'D vitamini');
    await tester.enterText(find.byType(TextField).last, 'Sabah - Tok');
    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('D vitamini'), findsWidgets);
  });

  testWidgets('vazgeçilince de çökme olmaz', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField).first, 'Yazıldı ama iptal');
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('boş ad ile eklenmez ve çökme olmaz', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
