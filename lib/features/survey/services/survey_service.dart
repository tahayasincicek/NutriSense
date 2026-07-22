// =============================================================================
// lib/features/survey/services/survey_service.dart
// NutriSense — Anket Kaydetme Servisi
//
// Lokal (SharedPreferences) + Uzak (Backend API) kayıt.
// İnternet yoksa lokal kaydet, sonra senkronize et.
// =============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../models/research_runtime_config.dart';
import '../models/survey_model.dart';
import '../../../shared/services/api_service.dart';

class _Keys {
  static const pendingSurveys = 'pending_surveys';
  static const completedSurveyIds = 'completed_survey_ids';
  static const usabilitySessions = 'usability_sessions';
  static const pendingUsabilitySessions = 'pending_usability_sessions';
  static const researchParticipantId = 'research_participant_id';
  static const researchWithdrawalCode = 'research_withdrawal_code';
}

class SurveyService {
  final ApiService _api;
  final FlutterSecureStorage _storage;
  final ResearchRuntimeConfig config;

  SurveyService({
    required ApiService api,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    ResearchRuntimeConfig? config,
  })  : _api = api,
        _storage = storage,
        config = config ?? ResearchRuntimeConfig.fromEnvironment();

  Future<List<String>> _readList(String key) async {
    final encoded = await _storage.read(key: key);
    if (encoded == null || encoded.isEmpty) return [];
    try {
      return (jsonDecode(encoded) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeList(String key, List<String> value) =>
      _storage.write(key: key, value: jsonEncode(value));

  Future<Map<String, dynamic>> recordConsent({
    required String consentMethod,
    String? witnessReference,
    String? evidenceReference,
  }) async {
    config.assertCollectionAllowed();
    final response = await _api.createResearchConsent({
      'data_origin': config.dataOrigin,
      'protocol_version': config.protocolVersion,
      'consent_version': config.consentVersion,
      'consent_method': consentMethod,
      if (witnessReference != null) 'witness_reference': witnessReference,
      if (evidenceReference != null) 'evidence_reference': evidenceReference,
    });
    if (!response.isSuccess || response.data == null) {
      throw const ResearchGateException('Araştırma onamı kaydedilemedi.');
    }
    final data = response.data!;
    await _storage.write(
      key: _Keys.researchParticipantId,
      value: data['participant_id']?.toString(),
    );
    await _storage.write(
      key: _Keys.researchWithdrawalCode,
      value: data['withdrawal_code']?.toString(),
    );
    return data;
  }

  Future<bool> withdrawResearchData({String? withdrawalCode}) async {
    final participantId = await _storage.read(key: _Keys.researchParticipantId);
    final code = withdrawalCode ??
        await _storage.read(key: _Keys.researchWithdrawalCode);
    if (participantId == null || code == null) return false;
    final response = await _api.withdrawResearchData({
      'participant_id': participantId,
      'withdrawal_code': code,
    });
    if (!response.isSuccess) return false;
    await clearLocalResearchData();
    return true;
  }

  Future<void> clearLocalResearchData() async {
    for (final key in [
      _Keys.pendingSurveys,
      _Keys.completedSurveyIds,
      _Keys.usabilitySessions,
      _Keys.pendingUsabilitySessions,
      _Keys.researchParticipantId,
      _Keys.researchWithdrawalCode,
    ]) {
      await _storage.delete(key: key);
    }
  }

  /// Hesap UUID'sinden bağımsız, yalnız araştırma alanında kullanılan takma kimlik.
  Future<String> getOrCreateResearchParticipantId() async {
    config.assertCollectionAllowed();
    var participantId = await _storage.read(key: _Keys.researchParticipantId);
    if (config.mode == ResearchMode.approved &&
        (participantId == null || participantId.isEmpty)) {
      throw const ResearchGateException(
        'Etkin onam olmadan katılımcı oturumu başlatılamaz.',
      );
    }
    if (participantId == null || participantId.isEmpty) {
      participantId = const Uuid().v4();
      await _storage.write(
          key: _Keys.researchParticipantId, value: participantId);
    }
    await _removeLegacyAccountIdentifiers(participantId);
    return participantId;
  }

  Future<void> _removeLegacyAccountIdentifiers(String participantId) async {
    final pending = await _readList(_Keys.pendingSurveys);
    final migrated = pending.map((encoded) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
        data.remove('user_id');
        data['participant_id'] = participantId;
        return jsonEncode(data);
      } catch (_) {
        return encoded;
      }
    }).toList();
    await _writeList(_Keys.pendingSurveys, migrated);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CİHAZ BİLGİSİ
  // ─────────────────────────────────────────────────────────────────────────

  /// Cihaz bilgisini toplar (anonim)
  Future<String> getDeviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return 'Android ${info.version.release} | ${info.model}';
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return 'iOS ${info.systemVersion} | ${info.model}';
      }
    } catch (_) {}
    return 'Bilinmeyen cihaz';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANKET KAYDETME
  // ─────────────────────────────────────────────────────────────────────────

  /// Anket sonuçlarını kaydeder (lokal + uzak)
  Future<bool> submitSurvey(SurveySubmission submission) async {
    config.assertCollectionAllowed();
    final participantId = await getOrCreateResearchParticipantId();
    final payload = submission.toJson()
      ..['participant_id'] = participantId
      ..['protocol_version'] = config.protocolVersion
      ..['data_origin'] = config.dataOrigin;

    // 1. Lokal kaydet (her durumda)
    await _saveLocally(payload);

    // 2. API'ye gönder
    try {
      final response = await _api.submitSurvey(payload);

      if (response.isSuccess) {
        // Başarılı — pending listesinden kaldır
        await _removePending(submission.id);
        await _markCompleted(submission.id);

        return true;
      }
    } catch (_) {
      // Lokal zaten kaydedildi
    }

    return false;
  }

  /// Bekleyen anketleri senkronize et
  Future<void> syncPendingSurveys() async {
    config.assertCollectionAllowed();
    final participantId = await getOrCreateResearchParticipantId();

    final pendingJson = await _readList(_Keys.pendingSurveys);
    final synced = <String>[];

    for (final json in pendingJson) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(json) as Map);
        data.remove('user_id');
        data['participant_id'] = participantId;
        data['protocol_version'] = config.protocolVersion;
        data['data_origin'] = config.dataOrigin;
        final response = await _api.submitSurvey(
          data,
        );
        if (response.isSuccess) {
          synced.add(json);
          await _markCompleted(data['id']);
        }
      } catch (_) {
        // Sonraki senkronizasyonda dene
      }
    }

    // Başarıyla gönderilenleri kaldır
    if (synced.isNotEmpty) {
      final remaining = pendingJson.where((j) => !synced.contains(j)).toList();
      await _writeList(_Keys.pendingSurveys, remaining);
    }
  }

  /// Lokal kayıt
  Future<void> _saveLocally(Map<String, dynamic> payload) async {
    final list = await _readList(_Keys.pendingSurveys);
    list.removeWhere((item) {
      try {
        return jsonDecode(item)['id'] == payload['id'];
      } catch (_) {
        return false;
      }
    });
    list.add(jsonEncode(payload));
    await _writeList(_Keys.pendingSurveys, list);
  }

  Future<void> _removePending(String id) async {
    final list = await _readList(_Keys.pendingSurveys);
    list.removeWhere((j) {
      try {
        return jsonDecode(j)['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await _writeList(_Keys.pendingSurveys, list);
  }

  Future<void> _markCompleted(String id) async {
    final ids = await _readList(_Keys.completedSurveyIds);
    if (!ids.contains(id)) {
      ids.add(id);
      await _writeList(_Keys.completedSurveyIds, ids);
    }
  }

  /// Anket daha önce tamamlandı mı?
  Future<bool> isSurveyCompleted() async {
    final ids = await _readList(_Keys.completedSurveyIds);
    return ids.isNotEmpty;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KULLANILABILIRLIK TESTİ
  // ─────────────────────────────────────────────────────────────────────────

  /// Kullanılabilirlik test oturumunu lokal kaydet
  Future<void> saveUsabilitySession(UsabilitySession session) async {
    config.assertCollectionAllowed();
    final participantId = await getOrCreateResearchParticipantId();
    final payload = session.toJson()
      ..['participant_id'] = participantId
      ..['protocol_version'] = config.protocolVersion
      ..['data_origin'] = config.dataOrigin;
    final list = await _readList(_Keys.usabilitySessions);
    list.add(jsonEncode(payload));
    await _writeList(_Keys.usabilitySessions, list);
    final pending = await _readList(_Keys.pendingUsabilitySessions);
    pending.add(jsonEncode(payload));
    await _writeList(_Keys.pendingUsabilitySessions, pending);
    final response = await _api.submitUsability(payload);
    if (response.isSuccess) {
      pending.removeWhere((item) {
        try {
          return jsonDecode(item)['id'] == session.id;
        } catch (_) {
          return false;
        }
      });
      await _writeList(_Keys.pendingUsabilitySessions, pending);
    }
  }

  Future<void> syncPendingUsabilitySessions() async {
    config.assertCollectionAllowed();
    final participantId = await getOrCreateResearchParticipantId();
    final pending = await _readList(_Keys.pendingUsabilitySessions);
    final synced = <String>[];
    for (final encoded in pending) {
      try {
        final payload = Map<String, dynamic>.from(jsonDecode(encoded) as Map)
          ..['participant_id'] = participantId
          ..['protocol_version'] = config.protocolVersion
          ..['data_origin'] = config.dataOrigin;
        final response = await _api.submitUsability(payload);
        if (response.isSuccess) synced.add(encoded);
      } catch (_) {
        // Keep the encrypted entry for the next explicit synchronization.
      }
    }
    if (synced.isNotEmpty) {
      await _writeList(
        _Keys.pendingUsabilitySessions,
        pending.where((item) => !synced.contains(item)).toList(),
      );
    }
  }

  /// Tüm oturumları JSON olarak dışa aktar
  Future<String> exportAllSessions() async {
    if (config.mode == ResearchMode.approved) {
      throw const ResearchGateException(
        'Gerçek katılımcı verisi cihazdan dışa aktarılamaz; yetkili backend export kullanın.',
      );
    }
    final list = await _readList(_Keys.usabilitySessions);
    final sessions = list.map((j) => jsonDecode(j)).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'export_date': DateTime.now().toIso8601String(),
      'total_sessions': sessions.length,
      'sessions': sessions,
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RIVERPOD PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

final surveyServiceProvider = Provider<SurveyService>((ref) {
  return SurveyService(api: ref.read(apiServiceProvider));
});
