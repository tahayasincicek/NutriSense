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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/survey_model.dart';
import '../../../shared/services/api_service.dart';

/// SharedPreferences anahtarları
class _Keys {
  static const pendingSurveys = 'pending_surveys';
  static const completedSurveyIds = 'completed_survey_ids';
  static const usabilitySessions = 'usability_sessions';
  static const researchParticipantId = 'research_participant_id';
}

class SurveyService {
  final ApiService _api;
  SharedPreferences? _prefs;

  SurveyService({required ApiService api}) : _api = api;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Hesap UUID'sinden bağımsız, yalnız araştırma alanında kullanılan takma kimlik.
  Future<String> getOrCreateResearchParticipantId() async {
    await _initPrefs();
    var participantId = _prefs!.getString(_Keys.researchParticipantId);
    if (participantId == null || participantId.isEmpty) {
      participantId = const Uuid().v4();
      await _prefs!.setString(_Keys.researchParticipantId, participantId);
    }
    await _removeLegacyAccountIdentifiers(participantId);
    return participantId;
  }

  Future<void> _removeLegacyAccountIdentifiers(String participantId) async {
    final pending = _prefs!.getStringList(_Keys.pendingSurveys) ?? [];
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
    await _prefs!.setStringList(_Keys.pendingSurveys, migrated);
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
    await _initPrefs();

    // 1. Lokal kaydet (her durumda)
    await _saveLocally(submission);

    // 2. API'ye gönder
    try {
      final response = await _api.submitSurvey(submission.toJson());

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
    await _initPrefs();
    final participantId = await getOrCreateResearchParticipantId();

    final pendingJson = _prefs!.getStringList(_Keys.pendingSurveys) ?? [];
    final synced = <String>[];

    for (final json in pendingJson) {
      try {
        final data = Map<String, dynamic>.from(jsonDecode(json) as Map);
        data.remove('user_id');
        data['participant_id'] = participantId;
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
      await _prefs!.setStringList(_Keys.pendingSurveys, remaining);
    }
  }

  /// Lokal kayıt
  Future<void> _saveLocally(SurveySubmission submission) async {
    final list = _prefs!.getStringList(_Keys.pendingSurveys) ?? [];
    list.add(jsonEncode(submission.toJson()));
    await _prefs!.setStringList(_Keys.pendingSurveys, list);
  }

  Future<void> _removePending(String id) async {
    final list = _prefs!.getStringList(_Keys.pendingSurveys) ?? [];
    list.removeWhere((j) {
      try {
        return jsonDecode(j)['id'] == id;
      } catch (_) {
        return false;
      }
    });
    await _prefs!.setStringList(_Keys.pendingSurveys, list);
  }

  Future<void> _markCompleted(String id) async {
    final ids = _prefs!.getStringList(_Keys.completedSurveyIds) ?? [];
    if (!ids.contains(id)) {
      ids.add(id);
      await _prefs!.setStringList(_Keys.completedSurveyIds, ids);
    }
  }

  /// Anket daha önce tamamlandı mı?
  Future<bool> isSurveyCompleted() async {
    await _initPrefs();
    final ids = _prefs!.getStringList(_Keys.completedSurveyIds) ?? [];
    return ids.isNotEmpty;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KULLANILABILIRLIK TESTİ
  // ─────────────────────────────────────────────────────────────────────────

  /// Kullanılabilirlik test oturumunu lokal kaydet
  Future<void> saveUsabilitySession(UsabilitySession session) async {
    await _initPrefs();
    final list = _prefs!.getStringList(_Keys.usabilitySessions) ?? [];
    list.add(jsonEncode(session.toJson()));
    await _prefs!.setStringList(_Keys.usabilitySessions, list);
    await _api.submitUsability(session.toJson());
  }

  /// Tüm oturumları JSON olarak dışa aktar
  Future<String> exportAllSessions() async {
    await _initPrefs();
    final list = _prefs!.getStringList(_Keys.usabilitySessions) ?? [];
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
