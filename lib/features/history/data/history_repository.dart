import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/food_analysis_model.dart';
import '../../../shared/services/api_service.dart';
import 'history_cache_store.dart';

abstract interface class HistoryRepository {
  Future<ApiResult<FoodHistoryResult>> fetch({
    required DateTime fromDate,
    required DateTime toDate,
    required int page,
    required int pageSize,
  });

  Future<HistoryCacheSnapshot?> readCache(String userId);
  Future<void> writeCache(String userId, FoodHistoryResult history);

  Future<ApiResult<FoodLogEntry>> update({
    required String logId,
    String? foodNameTr,
    double? portionGrams,
    String? mealType,
  });

  Future<ApiResult<Map<String, dynamic>>> delete(String logId);
  Future<ApiResult<Map<String, dynamic>>> restore(String logId);
}

class ApiHistoryRepository implements HistoryRepository {
  const ApiHistoryRepository(this._api, this._cache);

  final ApiService _api;
  final HistoryCacheStore _cache;

  @override
  Future<ApiResult<FoodHistoryResult>> fetch({
    required DateTime fromDate,
    required DateTime toDate,
    required int page,
    required int pageSize,
  }) {
    return _api.getFoodHistory(
      fromDate: fromDate,
      toDate: toDate,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<HistoryCacheSnapshot?> readCache(String userId) => _cache.read(userId);

  @override
  Future<void> writeCache(String userId, FoodHistoryResult history) =>
      _cache.write(userId, history);

  @override
  Future<ApiResult<FoodLogEntry>> update({
    required String logId,
    String? foodNameTr,
    double? portionGrams,
    String? mealType,
  }) {
    return _api.updateFoodLog(
      logId: logId,
      foodNameTr: foodNameTr,
      portionGrams: portionGrams,
      mealType: mealType,
    );
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> delete(String logId) =>
      _api.deleteFoodLog(logId: logId);

  @override
  Future<ApiResult<Map<String, dynamic>>> restore(String logId) =>
      _api.restoreFoodLog(logId: logId);
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return ApiHistoryRepository(
    ref.read(apiServiceProvider),
    ref.read(historyCacheStoreProvider),
  );
});
