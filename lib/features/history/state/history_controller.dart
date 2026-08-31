import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/app_clock.dart';
import '../../../shared/models/food_analysis_model.dart';
import '../../auth/state/auth_controller.dart';
import '../data/history_repository.dart';

enum HistoryStatus {
  initial,
  loading,
  data,
  empty,
  offlineCache,
  refreshing,
  error,
}

enum HistoryPeriod {
  daily('Günlük', 1),
  weekly('Haftalık', 7),
  monthly('Aylık', 30);

  const HistoryPeriod(this.label, this.days);
  final String label;
  final int days;
}

class HistoryState {
  const HistoryState({
    this.status = HistoryStatus.initial,
    this.period = HistoryPeriod.daily,
    this.anchorDate,
    this.history,
    this.cachedAt,
    this.message,
    this.errorCode,
  });

  final HistoryStatus status;
  final HistoryPeriod period;
  final DateTime? anchorDate;
  final FoodHistoryResult? history;
  final DateTime? cachedAt;
  final String? message;
  final String? errorCode;

  bool get hasData => history != null && history!.dailyLogs.isNotEmpty;
  bool get isRefreshing => status == HistoryStatus.refreshing;
  bool get isOffline => status == HistoryStatus.offlineCache;
  bool get authRequired => errorCode == 'AUTH_REQUIRED';

  HistoryState copyWith({
    HistoryStatus? status,
    HistoryPeriod? period,
    DateTime? anchorDate,
    FoodHistoryResult? history,
    DateTime? cachedAt,
    String? message,
    String? errorCode,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return HistoryState(
      status: status ?? this.status,
      period: period ?? this.period,
      anchorDate: anchorDate ?? this.anchorDate,
      history: history ?? this.history,
      cachedAt: cachedAt ?? this.cachedAt,
      message: clearMessage ? null : message ?? this.message,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
    );
  }
}

class HistoryActionResult {
  const HistoryActionResult.success(this.message) : isSuccess = true;
  const HistoryActionResult.failure(this.message) : isSuccess = false;

  final bool isSuccess;
  final String message;
}

class HistoryController extends StateNotifier<HistoryState> {
  HistoryController(
    this._repository,
    this._userId, {
    AppClock clock = const SystemAppClock(),
  })  : _clock = clock,
        super(HistoryState(anchorDate: clock.nowLocal()));

  final HistoryRepository _repository;
  final String? _userId;
  final AppClock _clock;
  static const _pageSize = 7;

  Future<void> load({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      state = state.copyWith(
        status: HistoryStatus.error,
        message: 'Beslenme geçmişinizi görmek için lütfen oturum açın.',
        errorCode: 'AUTH_REQUIRED',
      );
      return;
    }

    final previous = state.history;
    state = state.copyWith(
      status: refresh && previous != null
          ? HistoryStatus.refreshing
          : HistoryStatus.loading,
      clearError: true,
      clearMessage: true,
    );
    final range = _dateRange();
    final result = await _repository.fetch(
      fromDate: range.$1,
      toDate: range.$2,
      page: 1,
      pageSize: _pageSize,
    );

    if (result.isSuccess && result.data != null) {
      final history = result.data!;
      await _repository.writeCache(userId, history);
      state = state.copyWith(
        status: history.dailyLogs.isEmpty
            ? HistoryStatus.empty
            : HistoryStatus.data,
        history: history,
        cachedAt: _clock.nowUtc(),
        clearError: true,
        clearMessage: true,
      );
      return;
    }

    if (previous != null && previous.dailyLogs.isNotEmpty) {
      state = state.copyWith(
        status: HistoryStatus.offlineCache,
        history: previous,
        message: 'Çevrim dışı kayıtlar gösteriliyor; '
            'bağlantı kurulamadı.',
        errorCode: result.errorCode,
      );
      return;
    }

    final cached = await _repository.readCache(userId);
    if (cached != null && _cacheMatchesRange(cached.history, range)) {
      state = state.copyWith(
        status: HistoryStatus.offlineCache,
        history: cached.history,
        cachedAt: cached.cachedAt,
        message: 'Çevrim dışı kayıtlar gösteriliyor; '
            'son güvenli kopya kullanılıyor.',
        errorCode: result.errorCode,
      );
      return;
    }

    state = state.copyWith(
      status: HistoryStatus.error,
      message: result.errorMessage ?? 'Beslenme geçmişi yüklenemedi.',
      errorCode: result.errorCode,
    );
  }

  Future<void> refresh() => load(refresh: true);

  Future<void> setPeriod(HistoryPeriod period) async {
    state = HistoryState(period: period, anchorDate: _clock.nowLocal());
    await load();
  }

  Future<void> selectDate(DateTime date) async {
    state = HistoryState(period: HistoryPeriod.daily, anchorDate: date);
    await load();
  }

  Future<void> loadMore() async {
    final current = state.history;
    if (_userId == null ||
        current == null ||
        !current.hasMore ||
        state.isRefreshing) {
      return;
    }
    state = state.copyWith(status: HistoryStatus.refreshing);
    final result = await _repository.fetch(
      fromDate: current.fromDate,
      toDate: current.toDate,
      page: current.page + 1,
      pageSize: current.pageSize,
    );
    if (!result.isSuccess || result.data == null) {
      state = state.copyWith(
        status: HistoryStatus.offlineCache,
        message: result.errorMessage ?? 'Sonraki sayfa yüklenemedi.',
        errorCode: result.errorCode,
      );
      return;
    }
    final next = result.data!;
    final merged = FoodHistoryResult(
      userId: next.userId,
      fromDate: next.fromDate,
      toDate: next.toDate,
      totalDays: next.totalDays,
      averageDailyCalories: next.averageDailyCalories,
      totalCalories: next.totalCalories,
      totalLogCount: next.totalLogCount,
      totalDateCount: next.totalDateCount,
      page: next.page,
      pageSize: next.pageSize,
      hasMore: next.hasMore,
      dailyLogs: [...current.dailyLogs, ...next.dailyLogs],
    );
    await _repository.writeCache(_userId, merged);
    state = state.copyWith(
      status: HistoryStatus.data,
      history: merged,
      cachedAt: _clock.nowUtc(),
      clearError: true,
      clearMessage: true,
    );
  }

  Future<HistoryActionResult> updateEntry({
    required String logId,
    String? foodNameTr,
    double? portionGrams,
    String? mealType,
  }) async {
    final result = await _repository.update(
      logId: logId,
      foodNameTr: foodNameTr,
      portionGrams: portionGrams,
      mealType: mealType,
    );
    if (!result.isSuccess) {
      return HistoryActionResult.failure(
        result.errorMessage ?? 'Düzeltme kaydedilemedi.',
      );
    }
    await refresh();
    return const HistoryActionResult.success('Kayıt düzeltildi.');
  }

  Future<HistoryActionResult> deleteEntry(String logId) async {
    final result = await _repository.delete(logId);
    if (!result.isSuccess) {
      return HistoryActionResult.failure(
        result.errorMessage ?? 'Kayıt silinemedi.',
      );
    }
    await refresh();
    return const HistoryActionResult.success('Kayıt silindi.');
  }

  Future<HistoryActionResult> restoreEntry(String logId) async {
    final result = await _repository.restore(logId);
    if (!result.isSuccess) {
      return HistoryActionResult.failure(
        result.errorMessage ?? 'Kayıt geri alınamadı.',
      );
    }
    await refresh();
    return const HistoryActionResult.success('Kayıt geri alındı.');
  }

  (DateTime, DateTime) _dateRange() {
    final anchor = state.anchorDate ?? _clock.nowLocal();
    final toDate = DateTime(anchor.year, anchor.month, anchor.day);
    final fromDate = toDate.subtract(Duration(days: state.period.days - 1));
    return (fromDate, toDate);
  }

  bool _cacheMatchesRange(
    FoodHistoryResult cached,
    (DateTime, DateTime) range,
  ) {
    return _sameDay(cached.fromDate, range.$1) &&
        _sameDay(cached.toDate, range.$2);
  }

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

final historyUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.status == AuthStatus.authenticated ? auth.user?.id : null;
});

final historyControllerProvider =
    StateNotifierProvider<HistoryController, HistoryState>((ref) {
  return HistoryController(
    ref.read(historyRepositoryProvider),
    ref.watch(historyUserIdProvider),
    clock: ref.read(appClockProvider),
  );
});
