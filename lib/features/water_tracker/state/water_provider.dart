// =============================================================================
// lib/features/water_tracker/state/water_provider.dart
// NutriSense — Sağlık ve Aktivite Durumu
//
// Su, adım, uyku, ruh hâli, kilo ve takviye takibi. Veriler SharedPreferences
// ile cihazda saklanır; günlük ölçümler tarih değişince sıfırlanır.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/api_service.dart';

const _kStateKey = 'activity_state_v1';
const _kDayKey = 'activity_state_day';

class BadgeModel {
  const BadgeModel({
    required this.title,
    required this.icon,
    required this.description,
    this.isUnlocked = false,
  });

  final String title;
  final String icon;

  /// Rozetin hangi davranışla kazanıldığı; ekran okuyucu bunu okur.
  final String description;
  final bool isUnlocked;
}

/// İlaç / takviye hatırlatması.
class MedicationModel {
  const MedicationModel({
    required this.name,
    required this.schedule,
    this.isTaken = false,
  });

  final String name;
  final String schedule;
  final bool isTaken;

  MedicationModel copyWith({bool? isTaken}) => MedicationModel(
        name: name,
        schedule: schedule,
        isTaken: isTaken ?? this.isTaken,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'schedule': schedule,
        'isTaken': isTaken,
      };

  factory MedicationModel.fromJson(Map<String, dynamic> json) =>
      MedicationModel(
        name: json['name'] as String? ?? '',
        schedule: json['schedule'] as String? ?? '',
        isTaken: json['isTaken'] as bool? ?? false,
      );
}

class ActivityState {
  const ActivityState({
    this.consumedWater = 0,
    this.waterGoal = 2500,
    this.steps = 0,
    this.stepGoal = 10000,
    this.currentWeight,
    this.weightHistory = const [],
    this.currentMood,
    this.sleepHours = 0,
    this.sleepGoal = 8.0,
    this.medications = const [],
    this.isLoaded = false,
  });

  final int consumedWater;
  final int waterGoal;
  final int steps;
  final int stepGoal;

  /// Kullanıcı girene kadar boştur; uydurma bir başlangıç değeri gösterilmez.
  final double? currentWeight;
  final List<double> weightHistory;
  final String? currentMood;
  final double sleepHours;
  final double sleepGoal;
  final List<MedicationModel> medications;

  /// Kayıtlı veri okunana kadar false; ekran bu sırada boş değer göstermez.
  final bool isLoaded;

  double get waterProgress =>
      waterGoal <= 0 ? 0 : (consumedWater / waterGoal).clamp(0.0, 1.0);
  double get stepProgress =>
      stepGoal <= 0 ? 0 : (steps / stepGoal).clamp(0.0, 1.0);
  double get sleepProgress =>
      sleepGoal <= 0 ? 0 : (sleepHours / sleepGoal).clamp(0.0, 1.0);

  bool get hasWeight => currentWeight != null;

  /// Rozetler gerçek ilerlemeden türetilir; hepsi baştan açık değildir.
  List<BadgeModel> get badges => [
        BadgeModel(
          title: 'Su Avcısı',
          icon: '💧',
          description: 'Günlük su hedefini tamamla',
          isUnlocked: consumedWater >= waterGoal,
        ),
        BadgeModel(
          title: 'Yolcu',
          icon: '👟',
          description: 'Günlük adım hedefini tamamla',
          isUnlocked: steps >= stepGoal,
        ),
        BadgeModel(
          title: 'Uykucu',
          icon: '🌙',
          description: 'Uyku hedefine ulaş',
          isUnlocked: sleepHours >= sleepGoal,
        ),
        BadgeModel(
          title: 'Takipçi',
          icon: '⚖️',
          description: 'En az üç kilo ölçümü kaydet',
          isUnlocked: weightHistory.length >= 3,
        ),
      ];

  ActivityState copyWith({
    int? consumedWater,
    int? waterGoal,
    int? steps,
    int? stepGoal,
    double? currentWeight,
    List<double>? weightHistory,
    String? currentMood,
    double? sleepHours,
    double? sleepGoal,
    List<MedicationModel>? medications,
    bool? isLoaded,
  }) {
    return ActivityState(
      consumedWater: consumedWater ?? this.consumedWater,
      waterGoal: waterGoal ?? this.waterGoal,
      steps: steps ?? this.steps,
      stepGoal: stepGoal ?? this.stepGoal,
      currentWeight: currentWeight ?? this.currentWeight,
      weightHistory: weightHistory ?? this.weightHistory,
      currentMood: currentMood ?? this.currentMood,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepGoal: sleepGoal ?? this.sleepGoal,
      medications: medications ?? this.medications,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  Map<String, dynamic> toJson() => {
        'consumedWater': consumedWater,
        'waterGoal': waterGoal,
        'steps': steps,
        'stepGoal': stepGoal,
        'currentWeight': currentWeight,
        'weightHistory': weightHistory,
        'currentMood': currentMood,
        'sleepHours': sleepHours,
        'sleepGoal': sleepGoal,
        'medications': medications.map((item) => item.toJson()).toList(),
      };

  factory ActivityState.fromJson(Map<String, dynamic> json) => ActivityState(
        consumedWater: json['consumedWater'] as int? ?? 0,
        waterGoal: json['waterGoal'] as int? ?? 2500,
        steps: json['steps'] as int? ?? 0,
        stepGoal: json['stepGoal'] as int? ?? 10000,
        currentWeight: (json['currentWeight'] as num?)?.toDouble(),
        weightHistory: (json['weightHistory'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList(growable: false),
        currentMood: json['currentMood'] as String?,
        sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 0,
        sleepGoal: (json['sleepGoal'] as num?)?.toDouble() ?? 8.0,
        medications: (json['medications'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MedicationModel.fromJson)
            .toList(growable: false),
        isLoaded: true,
      );
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  ActivityNotifier(this._api) : super(const ActivityState()) {
    _restore();
  }

  /// Sunucu erişilemezse ölçümler yalnız cihazda tutulur; kullanıcı veri
  /// girişini kaybetmez.
  final ApiService? _api;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Kayıtlı durumu okur.
  ///
  /// Günlük ölçümler (su, adım, uyku, ruh hâli, takviye) tarih değişince
  /// sıfırlanır; hedefler, kilo geçmişi ve takviye listesi korunur.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStateKey);
      if (raw == null) {
        state = state.copyWith(isLoaded: true);
        return;
      }
      var restored = ActivityState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (prefs.getString(_kDayKey) != _today()) {
        // copyWith null'ı "değiştirme" saydığı için ruh hâlini temizlemek
        // adına durum açıkça kurulur.
        restored = ActivityState(
          consumedWater: 0,
          waterGoal: restored.waterGoal,
          steps: 0,
          stepGoal: restored.stepGoal,
          currentWeight: restored.currentWeight,
          weightHistory: restored.weightHistory,
          currentMood: null,
          sleepHours: 0,
          sleepGoal: restored.sleepGoal,
          medications: restored.medications
              .map((item) => item.copyWith(isTaken: false))
              .toList(growable: false),
          isLoaded: true,
        );
      }
      state = restored;
    } catch (_) {
      // Bozuk kayıt kullanıcıyı kilitlememeli; varsayılanla devam edilir.
      state = state.copyWith(isLoaded: true);
    }
    await _pullFromServer();
  }

  /// Hesaba bağlı ölçümleri sunucudan çeker.
  ///
  /// Sunucu kaynağı esas alır: ölçümler cihazda değil hesapta yaşar, böylece
  /// uygulama silinse de veri kaybolmaz.
  Future<void> _pullFromServer() async {
    final api = _api;
    if (api == null) return;
    final daily = await api.getTodayHealthMetrics();
    final weights = await api.getWeightHistory();
    if (!mounted) return;

    var next = state;
    if (daily.isSuccess && daily.data != null) {
      final data = daily.data!;
      next = next.copyWith(
        consumedWater: data['water_ml'] as int? ?? next.consumedWater,
        steps: data['steps'] as int? ?? next.steps,
        sleepHours:
            (data['sleep_hours'] as num?)?.toDouble() ?? next.sleepHours,
        currentMood: data['mood'] as String?,
      );
    }
    if (weights.isSuccess && weights.data != null) {
      final history = (weights.data!['measurements'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((item) => (item['weight_kg'] as num).toDouble())
          .toList(growable: false);
      next = next.copyWith(
        weightHistory: history,
        currentWeight: (weights.data!['current_weight'] as num?)?.toDouble(),
      );
    }
    state = next.copyWith(isLoaded: true);
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStateKey, jsonEncode(state.toJson()));
      await prefs.setString(_kDayKey, _today());
    } catch (_) {
      // Depolama hatası ölçüm girişini engellememelidir.
    }
  }

  void addWater(int ml) {
    state = state.copyWith(
      consumedWater: (state.consumedWater + ml).clamp(0, 100000),
    );
    _persist();
    unawaited(_api?.updateTodayHealthMetrics(waterMl: state.consumedWater));
  }

  void addSteps(int count) {
    state = state.copyWith(steps: (state.steps + count).clamp(0, 500000));
    _persist();
    unawaited(_api?.updateTodayHealthMetrics(steps: state.steps));
  }

  void updateWeight(double weight) {
    if (weight <= 0 || weight > 500) return;
    final history = List<double>.from(state.weightHistory)..add(weight);
    // Grafik son ölçümlerle anlamlı; sınırsız büyümesine gerek yok.
    final trimmed =
        history.length > 30 ? history.sublist(history.length - 30) : history;
    state = state.copyWith(currentWeight: weight, weightHistory: trimmed);
    _persist();
    unawaited(_api?.addWeightMeasurement(weightKg: weight));
  }

  void setMood(String mood) {
    state = state.copyWith(currentMood: mood);
    _persist();
    unawaited(_api?.updateTodayHealthMetrics(mood: mood));
  }

  /// Uyku süresini saat cinsinden kaydeder. 0-24 aralığına sıkıştırılır.
  void setSleep(double hours) {
    state = state.copyWith(sleepHours: hours.clamp(0, 24));
    _persist();
    unawaited(_api?.updateTodayHealthMetrics(sleepHours: state.sleepHours));
  }

  /// Takip edilecek yeni bir takviye ekler.
  void addMedication(String name, String schedule) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (state.medications.any((item) => item.name == trimmed)) return;
    state = state.copyWith(
      medications: [
        ...state.medications,
        MedicationModel(name: trimmed, schedule: schedule.trim()),
      ],
    );
    _persist();
  }

  void removeMedication(String name) {
    state = state.copyWith(
      medications: state.medications
          .where((item) => item.name != name)
          .toList(growable: false),
    );
    _persist();
  }

  /// İlacın alındı durumunu tersine çevirir.
  void toggleMedication(String name) {
    state = state.copyWith(
      medications: state.medications
          .map((med) =>
              med.name == name ? med.copyWith(isTaken: !med.isTaken) : med)
          .toList(growable: false),
    );
    _persist();
  }
}

final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>(
    (ref) => ActivityNotifier(ref.read(apiServiceProvider)));
