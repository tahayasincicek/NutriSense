import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/time/app_clock.dart';

void main() {
  test('FixedAppClock zaman diliminden bağımsız aynı UTC anını döndürür', () {
    final clock = FixedAppClock(
      DateTime.parse('2026-07-26T12:30:00+03:00'),
    );

    expect(clock.nowUtc(), DateTime.parse('2026-07-26T09:30:00Z'));
    expect(clock.nowUtc(), clock.nowUtc());
  });
}
