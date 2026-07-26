import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Testlerde gerçek saate bağımlılığı kaldıran tek saat sınırı.
abstract class AppClock {
  const AppClock();

  DateTime nowUtc();

  DateTime nowLocal() => nowUtc().toLocal();
}

class SystemAppClock extends AppClock {
  const SystemAppClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

class FixedAppClock extends AppClock {
  const FixedAppClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value.toUtc();
}

final appClockProvider = Provider<AppClock>((ref) => const SystemAppClock());
