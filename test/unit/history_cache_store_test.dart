import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/history/data/history_cache_store.dart';
import 'package:nutrisense/shared/models/food_analysis_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('geçmiş önbelleği kullanıcıya göre ayrılır ve kayıpsız okunur',
      () async {
    const userId = '9e4e5356-b491-4575-a9dd-c5abbc777fe9';
    final history = _history();
    final store = SecureHistoryCacheStore();

    await store.write(userId, history);

    final restored = await store.read(userId);
    expect(restored, isNotNull);
    expect(restored!.history.userId, userId);
    expect(restored.history.dailyLogs.single.foods.single.foodNameTr, 'Elma');
    expect(await store.read('00000000-0000-4000-8000-000000000000'), isNull);
  });

  test('başka kullanıcıya ait veri yanlış cache anahtarına yazılamaz',
      () async {
    final store = SecureHistoryCacheStore();

    expect(
      () => store.write('00000000-0000-4000-8000-000000000000', _history()),
      throwsStateError,
    );
  });

  test('clearAll oturum kapanışında tüm kullanıcı cachelerini kaldırır',
      () async {
    const userId = '9e4e5356-b491-4575-a9dd-c5abbc777fe9';
    final store = SecureHistoryCacheStore();
    await store.write(userId, _history());

    await store.clearAll();

    expect(await store.read(userId), isNull);
  });
}

FoodHistoryResult _history() => FoodHistoryResult.fromJson(
      jsonDecode(
        File('contracts/fixtures/food_history_success.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );
