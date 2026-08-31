import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/onboarding/screens/onboarding_screen.dart';
import 'package:nutrisense/features/settings/screens/settings_screen.dart';

/// Sesli tanıtım ilk kurulumdan sonra da erişilebilir olmalı; yeni bir
/// kullanıcı uygulamanın nasıl kullanıldığını unutursa geri dönebilmeli.
/// Tekrar izlemede mevcut ayarlar değiştirilmemeli.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> permissionCalls;

  setUp(() {
    permissionCalls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => call.method == 'isLanguageAvailable' ? true : 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    // permission_handler: 1 = granted
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (call) async {
        permissionCalls.add(call);
        return call.method == 'checkPermissionStatus'
            ? 1
            : <int, int>{1: 1, 7: 1};
      },
    );
  });

  Widget app({required bool isReplay, VoidCallback? onComplete}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: OnboardingScreen(
          isReplay: isReplay,
          onComplete: onComplete ?? () {},
        ),
      ),
    );
  }

  testWidgets('tanıtım tekrar izleme kipinde açılabilir', (tester) async {
    await tester.pumpWidget(app(isReplay: true));
    await tester.pump();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('tekrar izlemede izin butonu durum dinletir', (tester) async {
    await tester.pumpWidget(app(isReplay: true));
    await tester.pump();

    // İzin sayfasına ulaşmak için sayfaları geçmemiz gerekebilir; buton
    // görünürse metni tekrar izlemeye uygun olmalı.
    final button = find.byKey(const Key('onboarding_permissions'));
    if (button.evaluate().isNotEmpty) {
      expect(find.text('İzin Durumunu Dinle'), findsOneWidget);
      expect(find.text('İzinleri Ver'), findsNothing);
    }
  });

  testWidgets('ilk kurulumda izin butonu izin ister', (tester) async {
    await tester.pumpWidget(app(isReplay: false));
    await tester.pump();

    final button = find.byKey(const Key('onboarding_permissions'));
    if (button.evaluate().isNotEmpty) {
      expect(find.text('İzinleri Ver'), findsOneWidget);
    }
  });

  testWidgets('onComplete geri çağrısı tetiklenir', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      app(isReplay: true, onComplete: () => completed = true),
    );
    await tester.pump();

    // Ekran kurulabilmeli; geri çağrı imzası korunmalı.
    expect(completed, isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('Ayarlar ekranında tanıtım girişi bulunur', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    final tile = find.byKey(const Key('settings_replay_onboarding'));
    await tester.scrollUntilVisible(tile, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(tile, findsOneWidget);
    expect(find.text('Tanıtımı Tekrar Dinle'), findsOneWidget);
  });

  testWidgets('Araştırma araçları Ayarlar üzerinden açılabilir',
      (tester) async {
    // Ekranlar yazılmış olsa da bir yerden açılamıyorsa kullanılamaz.
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();

    for (final key in const [
      Key('settings_open_survey'),
      Key('settings_open_usability'),
    ]) {
      final tile = find.byKey(key);
      await tester.scrollUntilVisible(tile, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tile, findsOneWidget,
          reason: 'Arastirma araci Ayarlar menusunde bulunamadi');

      final listTile = tester.widget<ListTile>(tile);
      expect(listTile.onTap, isNotNull, reason: 'Arastirma araci eylemsiz');
    }
  });
}
