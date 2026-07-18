import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../shared/models/food_analysis_model.dart';

class HistoryCacheSnapshot {
  const HistoryCacheSnapshot({required this.history, required this.cachedAt});

  final FoodHistoryResult history;
  final DateTime cachedAt;
}

abstract interface class HistoryCacheStore {
  Future<HistoryCacheSnapshot?> read(String userId);
  Future<void> write(String userId, FoodHistoryResult history);
  Future<void> clear(String userId);
  Future<void> clearAll();
}

/// Small, user-scoped read-only cache stored through Android Keystore/iOS Keychain.
/// Mutations are never queued here and SharedPreferences is not used for health data.
class SecureHistoryCacheStore implements HistoryCacheStore {
  SecureHistoryCacheStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _indexKey = 'food_history_cache_index_v1';
  static const _schemaVersion = 1;
  final FlutterSecureStorage _storage;

  String _key(String userId) => 'food_history_cache_v1_$userId';

  @override
  Future<HistoryCacheSnapshot?> read(String userId) async {
    final key = _key(userId);
    final encoded = await _storage.read(key: key);
    if (encoded == null) return null;
    try {
      final payload = jsonDecode(encoded) as Map<String, dynamic>;
      if (payload['schema_version'] != _schemaVersion ||
          payload['user_id'] != userId) {
        await clear(userId);
        return null;
      }
      return HistoryCacheSnapshot(
        history: FoodHistoryResult.fromJson(
          Map<String, dynamic>.from(payload['history'] as Map),
        ),
        cachedAt: DateTime.parse(payload['cached_at'] as String),
      );
    } catch (_) {
      await clear(userId);
      return null;
    }
  }

  @override
  Future<void> write(String userId, FoodHistoryResult history) async {
    if (history.userId != userId) {
      throw StateError('Başka kullanıcıya ait geçmiş önbelleğe yazılamaz.');
    }
    final key = _key(userId);
    await _storage.write(
      key: key,
      value: jsonEncode({
        'schema_version': _schemaVersion,
        'user_id': userId,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
        'history': history.toJson(),
      }),
    );
    final keys = (await _readIndex())..add(key);
    await _storage.write(key: _indexKey, value: jsonEncode(keys.toList()));
  }

  @override
  Future<void> clear(String userId) async {
    final key = _key(userId);
    await _storage.delete(key: key);
    final keys = (await _readIndex())..remove(key);
    if (keys.isEmpty) {
      await _storage.delete(key: _indexKey);
    } else {
      await _storage.write(key: _indexKey, value: jsonEncode(keys.toList()));
    }
  }

  @override
  Future<void> clearAll() async {
    final keys = await _readIndex();
    for (final key in keys) {
      await _storage.delete(key: key);
    }
    await _storage.delete(key: _indexKey);
  }

  Future<Set<String>> _readIndex() async {
    final encoded = await _storage.read(key: _indexKey);
    if (encoded == null) return <String>{};
    try {
      return (jsonDecode(encoded) as List).whereType<String>().toSet();
    } catch (_) {
      await _storage.delete(key: _indexKey);
      return <String>{};
    }
  }
}

final historyCacheStoreProvider = Provider<HistoryCacheStore>((ref) {
  return SecureHistoryCacheStore();
});
