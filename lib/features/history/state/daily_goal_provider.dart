// =============================================================================
// lib/features/history/state/daily_goal_provider.dart
// NutriSense — Günlük Kalori Hedefi Provider
//
// SharedPreferences ile günlük kalori hedefi yönetimi.
// Kalan kalori hesaplama ve hedefe yaklaşıldığında uyarı.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/services/accessibility_service.dart';
import 'history_controller.dart';

/// SharedPreferences anahtarı
const _kDailyGoalKey = 'daily_calorie_goal';
const _kDefaultGoal = 2000.0;

/// Günlük kalori hedefi durumu
class DailyGoalState {
  const DailyGoalState({
    this.goalCalories = _kDefaultGoal,
    this.consumedCalories = 0,
    this.isLoaded = false,
  });

  final double goalCalories;
  final double consumedCalories;
  final bool isLoaded;

  double get remainingCalories =>
      (goalCalories - consumedCalories).clamp(0, double.infinity);
  double get progress =>
      goalCalories > 0 ? (consumedCalories / goalCalories).clamp(0.0, 1.5) : 0;
  bool get isOverGoal => consumedCalories > goalCalories;
  bool get isNearGoal =>
      consumedCalories >= goalCalories * 0.8 &&
      consumedCalories <= goalCalories;
  int get progressPercent => (progress * 100).round();

  /// TTS için özet metin
  String get ttsSummary {
    if (isOverGoal) {
      return 'Günlük kalori hedefinizi ${(consumedCalories - goalCalories).toStringAsFixed(0)} kalori aştınız. '
          'Toplam ${consumedCalories.toStringAsFixed(0)} kalori tükettiniz.';
    }
    return 'Bugün ${consumedCalories.toStringAsFixed(0)} kalori tükettiniz. '
        '${goalCalories.toStringAsFixed(0)} kalorilik hedefinize '
        '${remainingCalories.toStringAsFixed(0)} kalori kaldı.';
  }

  DailyGoalState copyWith({
    double? goalCalories,
    double? consumedCalories,
    bool? isLoaded,
  }) {
    return DailyGoalState(
      goalCalories: goalCalories ?? this.goalCalories,
      consumedCalories: consumedCalories ?? this.consumedCalories,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

/// Günlük kalori hedefi controller
class DailyGoalController extends StateNotifier<DailyGoalState> {
  DailyGoalController(this._ref) : super(const DailyGoalState()) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final goal = prefs.getDouble(_kDailyGoalKey) ?? _kDefaultGoal;
    state = state.copyWith(goalCalories: goal, isLoaded: true);
    _syncWithHistory();
  }

  /// Geçmişten bugünkü toplam kaloriyi al
  void _syncWithHistory() {
    _ref.listen<HistoryState>(historyControllerProvider, (prev, next) {
      if (next.hasData && next.history != null) {
        final today = DateTime.now();
        double todayCalories = 0;
        for (final dailyLog in next.history!.dailyLogs) {
          if (dailyLog.date.year == today.year &&
              dailyLog.date.month == today.month &&
              dailyLog.date.day == today.day) {
            todayCalories = dailyLog.totalCalories;
            break;
          }
        }
        final oldConsumed = state.consumedCalories;
        state = state.copyWith(consumedCalories: todayCalories);

        // Hedefe yaklaşıldığında sesli uyarı
        if (todayCalories > oldConsumed && state.isNearGoal) {
          _announceGoalProgress();
        }
      }
    });
  }

  void _announceGoalProgress() {
    try {
      final accessibility = _ref.read(accessibilityServiceProvider);
      if (state.isOverGoal) {
        accessibility.speak(
          'Dikkat! Günlük kalori hedefinizi aştınız.',
          priority: TtsPriority.high,
        );
      } else if (state.isNearGoal) {
        accessibility.speak(
          'Günlük kalori hedefinizin yüzde ${state.progressPercent}\'ine ulaştınız. '
          '${state.remainingCalories.toStringAsFixed(0)} kalori kaldı.',
          priority: TtsPriority.normal,
        );
      }
    } catch (_) {
      // TTS servisi hazır olmayabilir
    }
  }

  /// Kalori hedefini güncelle
  Future<void> setGoal(double calories) async {
    final clamped = calories.clamp(500.0, 10000.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kDailyGoalKey, clamped);
    state = state.copyWith(goalCalories: clamped);
  }

  /// Tüketilen kaloriyi manuel güncelle (geçmişten bağımsız)
  void updateConsumed(double calories) {
    state = state.copyWith(consumedCalories: calories);
  }
}

final dailyGoalControllerProvider =
    StateNotifierProvider<DailyGoalController, DailyGoalState>((ref) {
  return DailyGoalController(ref);
});
