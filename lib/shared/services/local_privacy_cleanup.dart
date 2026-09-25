import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/food_scan/services/food_correction_sample_store.dart';
import '../utils/temporary_share_file.dart';

/// Removes account-linked data that can remain on a shared device.
///
/// Every cleanup step is attempted even if another platform storage operation
/// fails. The server-side logout/account deletion has already happened when
/// this runs, so a local filesystem error must not restore the session.
class LocalPrivacyCleanup {
  LocalPrivacyCleanup({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    required FoodCorrectionSampleStore correctionSamples,
  })  : _storage = storage,
        _correctionSamples = correctionSamples;

  final FlutterSecureStorage _storage;
  final FoodCorrectionSampleStore _correctionSamples;

  Future<void> clearAccountData() async {
    await Future.wait<void>([
      _bestEffort(_clearSecureAccountValues),
      _bestEffort(_clearLegacyPlaintextHealthValues),
      _bestEffort(_correctionSamples.clearAll),
      _bestEffort(purgeTemporaryShareFiles),
    ]);
  }

  Future<void> _clearSecureAccountValues() async {
    const historyIndexKey = 'food_history_cache_index_v1';
    final indexedHistoryKeys = <String>{};
    final encodedIndex = await _storage.read(key: historyIndexKey);
    if (encodedIndex != null) {
      try {
        indexedHistoryKeys.addAll(
          (jsonDecode(encodedIndex) as List).whereType<String>().where(
                (key) => key.startsWith('food_history_cache_v1_'),
              ),
        );
      } on Object {
        // Corrupt index is removed below with the other known keys.
      }
    }
    for (final key in {
      'auth_session_v1',
      'activity_state_v1',
      'activity_state_day',
      historyIndexKey,
      ...indexedHistoryKeys,
    }) {
      await _storage.delete(key: key);
    }
  }

  Future<void> _clearLegacyPlaintextHealthValues() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('activity_state_v1');
    await preferences.remove('activity_state_day');
  }

  Future<void> _bestEffort(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object {
      // The caller still completes logout. A later logout/delete attempt can
      // retry cleanup, while the in-memory authenticated session stays gone.
    }
  }
}
