import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/accessibility_service.dart';
import 'package:nutrisense/shared/services/speech_route_observer.dart';

/// Ekran değişince önceki ekranın sesli anlatımı susmalıdır.
///
/// Görme engelli kullanıcı için bu yalnız rahatsızlık değil, yanıltıcıdır:
/// duyduğu cümle artık ekranda olmayan bir içeriği anlatır.
void main() {
  testWidgets('yeni ekran açılınca konuşma kesilir', (tester) async {
    final service = _RecordingAccessibilityService();
    final observer = SpeechRouteObserver(service);

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('ilk ekran')),
      ),
    );
    // İlk ekranın açılışı kesilecek bir konuşma olmadığı için saymaz.
    expect(service.stopCount, 0);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('ikinci ekran')),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.stopCount, 1);
  });

  testWidgets('geri dönünce de konuşma kesilir', (tester) async {
    final service = _RecordingAccessibilityService();
    final observer = SpeechRouteObserver(service);

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('ilk ekran')),
      ),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('ikinci ekran')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    expect(service.stopCount, 2);
  });
}

class _RecordingAccessibilityService extends AccessibilityService {
  int stopCount = 0;

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}
