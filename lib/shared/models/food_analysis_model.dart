// =============================================================================
// lib/shared/models/food_analysis_model.dart
// NutriSense — API Yanıt Modelleri (JSON Serialization)
//
// Backend'den gelen yanıtları Dart nesnelerine dönüştürür.
// =============================================================================

/// Besin değerleri
class NutrientData {
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const NutrientData({
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
  });

  factory NutrientData.fromJson(Map<String, dynamic> json) {
    return NutrientData(
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
      };

  @override
  String toString() => 'P:${protein.toStringAsFixed(1)}g '
      'C:${carbs.toStringAsFixed(1)}g '
      'F:${fat.toStringAsFixed(1)}g';
}

/// POST /api/v1/analyze-food yanıtı
class FoodAnalysisResult {
  final String foodName;
  final String foodNameTr;
  final double caloriesPer100g;
  final double portionGrams;
  final double totalCalories;
  final double confidence;
  final NutrientData nutrients;
  final String mealType;
  final String logId;
  final String recognitionSource;
  final String nutritionSource;
  final bool needsConfirmation;
  final String ttsText;

  const FoodAnalysisResult({
    required this.foodName,
    required this.foodNameTr,
    required this.caloriesPer100g,
    required this.portionGrams,
    required this.totalCalories,
    required this.confidence,
    required this.nutrients,
    required this.mealType,
    required this.logId,
    required this.recognitionSource,
    required this.nutritionSource,
    required this.needsConfirmation,
    required this.ttsText,
  });

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    return FoodAnalysisResult(
      foodName: _requiredString(json, 'food_name'),
      foodNameTr: _requiredString(json, 'food_name_tr'),
      caloriesPer100g: (json['calories_per_100g'] as num?)?.toDouble() ?? 0,
      portionGrams: (json['portion_grams'] as num?)?.toDouble() ?? 0,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
      confidence: _confidence(json['confidence']),
      nutrients: NutrientData.fromJson(_mapOrEmpty(json['nutrients'])),
      mealType: json['meal_type'] ?? 'atistirmalik',
      logId: _requiredString(json, 'log_id'),
      recognitionSource: json['recognition_source'] as String? ?? 'unknown',
      nutritionSource: json['nutrition_source'] as String? ?? 'unknown',
      needsConfirmation: json['needs_confirmation'] as bool? ?? true,
      ttsText: json['tts_text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'food_name': foodName,
        'food_name_tr': foodNameTr,
        'calories_per_100g': caloriesPer100g,
        'portion_grams': portionGrams,
        'total_calories': totalCalories,
        'confidence': confidence,
        'nutrients': nutrients.toJson(),
        'meal_type': mealType,
        'log_id': logId,
        'recognition_source': recognitionSource,
        'nutrition_source': nutritionSource,
        'needs_confirmation': needsConfirmation,
        'tts_text': ttsText,
      };
}

Map<String, dynamic> _mapOrEmpty(dynamic value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('API alanı eksik veya geçersiz: $key');
  }
  return value;
}

double _confidence(dynamic value) {
  final confidence = value is num ? value.toDouble() : -1.0;
  if (confidence < 0 || confidence > 1) {
    throw const FormatException('confidence 0..1 aralığında olmalıdır');
  }
  return confidence;
}

/// Yemek geçmişi — tek besin kaydı
class FoodLogEntry {
  final String id;
  final String foodName;
  final String foodNameTr;
  final double calories;
  final double portionG;
  final String mealType;
  final double confidence;
  final NutrientData nutrients;
  final DateTime loggedAt;

  const FoodLogEntry({
    required this.id,
    required this.foodName,
    required this.foodNameTr,
    required this.calories,
    required this.portionG,
    required this.mealType,
    required this.confidence,
    required this.nutrients,
    required this.loggedAt,
  });

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) {
    return FoodLogEntry(
      id: json['id'] ?? '',
      foodName: json['food_name'] ?? '',
      foodNameTr: json['food_name_tr'] ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      portionG: (json['portion_g'] as num?)?.toDouble() ?? 0,
      mealType: json['meal_type'] ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      nutrients: NutrientData.fromJson(_mapOrEmpty(json['nutrients'])),
      loggedAt: DateTime.tryParse(json['logged_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Öğün bazlı özet
class MealSummaryData {
  final String mealType;
  final String mealTypeTr;
  final double totalCalories;
  final int foodCount;

  const MealSummaryData({
    required this.mealType,
    required this.mealTypeTr,
    required this.totalCalories,
    required this.foodCount,
  });

  factory MealSummaryData.fromJson(Map<String, dynamic> json) {
    return MealSummaryData(
      mealType: json['meal_type'] ?? '',
      mealTypeTr: json['meal_type_tr'] ?? '',
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
      foodCount: json['food_count'] ?? 0,
    );
  }
}

/// Günlük besin özeti
class DailyLog {
  final DateTime date;
  final double totalCalories;
  final double calorieTarget;
  final double remainingCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final int mealCount;
  final List<MealSummaryData> meals;
  final List<FoodLogEntry> foods;

  const DailyLog({
    required this.date,
    required this.totalCalories,
    required this.calorieTarget,
    required this.remainingCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.mealCount,
    required this.meals,
    required this.foods,
  });

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
      calorieTarget: (json['calorie_target'] as num?)?.toDouble() ?? 2000,
      remainingCalories: (json['remaining_calories'] as num?)?.toDouble() ?? 0,
      totalProtein: (json['total_protein'] as num?)?.toDouble() ?? 0,
      totalCarbs: (json['total_carbs'] as num?)?.toDouble() ?? 0,
      totalFat: (json['total_fat'] as num?)?.toDouble() ?? 0,
      mealCount: json['meal_count'] ?? 0,
      meals: (json['meals'] as List?)
              ?.map((m) => MealSummaryData.fromJson(m))
              .toList() ??
          [],
      foods: (json['foods'] as List?)
              ?.map((f) => FoodLogEntry.fromJson(f))
              .toList() ??
          [],
    );
  }
}

/// GET /api/v1/food-history yanıtı
class FoodHistoryResult {
  final String userId;
  final DateTime fromDate;
  final DateTime toDate;
  final int totalDays;
  final double averageDailyCalories;
  final double totalCalories;
  final List<DailyLog> dailyLogs;

  const FoodHistoryResult({
    required this.userId,
    required this.fromDate,
    required this.toDate,
    required this.totalDays,
    required this.averageDailyCalories,
    required this.totalCalories,
    required this.dailyLogs,
  });

  factory FoodHistoryResult.fromJson(Map<String, dynamic> json) {
    return FoodHistoryResult(
      userId: json['user_id'] ?? '',
      fromDate: DateTime.tryParse(json['from_date'] ?? '') ?? DateTime.now(),
      toDate: DateTime.tryParse(json['to_date'] ?? '') ?? DateTime.now(),
      totalDays: json['total_days'] ?? 0,
      averageDailyCalories:
          (json['average_daily_calories'] as num?)?.toDouble() ?? 0,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
      dailyLogs: (json['daily_logs'] as List?)
              ?.map((d) => DailyLog.fromJson(d))
              .toList() ??
          [],
    );
  }
}

/// POST /api/v1/send-to-dietitian yanıtı
class SendToDietitianResult {
  final bool success;
  final String reportId;
  final bool sentViaEmail;
  final bool sentViaSms;
  final String dietitianName;
  final String message;

  const SendToDietitianResult({
    required this.success,
    required this.reportId,
    required this.sentViaEmail,
    required this.sentViaSms,
    required this.dietitianName,
    required this.message,
  });

  factory SendToDietitianResult.fromJson(Map<String, dynamic> json) {
    return SendToDietitianResult(
      success: json['success'] ?? false,
      reportId: json['report_id'] ?? '',
      sentViaEmail: json['sent_via_email'] ?? false,
      sentViaSms: json['sent_via_sms'] ?? false,
      dietitianName: json['dietitian_name'] ?? '',
      message: json['message'] ?? '',
    );
  }
}

/// JWT token yanıtı
class AuthTokenResult {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final int refreshExpiresIn;
  final String userId;
  final String fullName;

  const AuthTokenResult({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.refreshExpiresIn,
    required this.userId,
    required this.fullName,
  });

  factory AuthTokenResult.fromJson(Map<String, dynamic> json) {
    return AuthTokenResult(
      accessToken: _requiredString(json, 'access_token'),
      refreshToken: _requiredString(json, 'refresh_token'),
      tokenType: json['token_type'] ?? 'bearer',
      expiresIn: json['expires_in'] ?? 0,
      refreshExpiresIn: json['refresh_expires_in'] ?? 0,
      userId: _requiredString(json, 'user_id'),
      fullName: json['full_name'] ?? '',
    );
  }
}

/// API hata yanıtı
class ApiErrorResult {
  final bool error;
  final String message;
  final String? detail;
  final String code;

  const ApiErrorResult({
    this.error = true,
    required this.message,
    this.detail,
    this.code = 'UNKNOWN_ERROR',
  });

  factory ApiErrorResult.fromJson(Map<String, dynamic> json) {
    return ApiErrorResult(
      error: json['error'] ?? true,
      message: json['message'] ?? 'Bilinmeyen bir hata oluştu.',
      detail: json['detail'],
      code: json['code'] ?? 'UNKNOWN_ERROR',
    );
  }
}
