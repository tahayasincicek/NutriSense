import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `Navigator.push` ile açılan ekranların arkasında AppShell boyaması yoktur;
/// saydam arka plan kullanırlarsa tema değişince (özellikle karanlık mod)
/// eski temanın rengi kalır. Bu ekranlar arka planı temadan almalıdır.
///
/// Sekme içindeki ekranlar (AppShell'in IndexedStack'i) bu kuralın dışındadır:
/// arkalarında kabuk kendi zeminini boyar.
void main() {
  const pushedScreens = <String>[
    'lib/features/settings/screens/settings_screen.dart',
    'lib/features/history/screens/nutrition_stats_screen.dart',
    'lib/features/food_scan/screens/manual_food_entry_screen.dart',
    'lib/features/food_scan/screens/nutrition_detail_screen.dart',
    'lib/features/auth/screens/password_reset_screen.dart',
    'lib/features/discover/screens/article_detail_screen.dart',
    'lib/features/discover/screens/category_screen.dart',
  ];

  for (final path in pushedScreens) {
    test('${path.split('/').last} saydam Scaffold arka planı kullanmaz', () {
      final file = File(path);
      if (!file.existsSync()) return;
      final source = file.readAsStringSync();

      // Scaffold'un doğrudan altındaki saydam arka plan sorunludur.
      expect(
        source.contains(
          'return Scaffold(\n      backgroundColor: Colors.transparent,',
        ),
        isFalse,
        reason: '$path saydam arka plan kullanıyor; karanlık modda '
            'arkasında eski tema rengi kalır',
      );
    });
  }
}
