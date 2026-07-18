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

class FoodCandidate {
  final String foodName;
  final String foodNameTr;
  final double confidence;

  const FoodCandidate({
    required this.foodName,
    required this.foodNameTr,
    required this.confidence,
  });

  factory FoodCandidate.fromJson(Map<String, dynamic> json) => FoodCandidate(
        foodName: _requiredString(json, 'food_name'),
        foodNameTr: _requiredString(json, 'food_name_tr'),
        confidence: _confidence(json['confidence']),
      );
}

class NutritionProvenance {
  final String source;
  final String sourceItemId;
  final String locale;
  final DateTime retrievedAt;
  final String servingUnit;
  final double servingGrams;
  final String licenseName;
  final String attribution;

  const NutritionProvenance({
    required this.source,
    required this.sourceItemId,
    required this.locale,
    required this.retrievedAt,
    required this.servingUnit,
    required this.servingGrams,
    required this.licenseName,
    required this.attribution,
  });

  factory NutritionProvenance.fromJson(Map<String, dynamic> json) =>
      NutritionProvenance(
        source: _requiredString(json, 'source'),
        sourceItemId: _requiredString(json, 'source_item_id'),
        locale: _requiredString(json, 'locale'),
        retrievedAt: DateTime.parse(_requiredString(json, 'retrieved_at')),
        servingUnit: _requiredString(json, 'serving_unit'),
        servingGrams: _positive(json['serving_grams'], 'serving_grams'),
        licenseName: _requiredString(json, 'license_name'),
        attribution: _requiredString(json, 'attribution'),
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'source_item_id': sourceItemId,
        'locale': locale,
        'retrieved_at': retrievedAt.toUtc().toIso8601String(),
        'serving_unit': servingUnit,
        'serving_grams': servingGrams,
        'license_name': licenseName,
        'attribution': attribution,
      };
}

class PortionOption {
  final String unit;
  final double gramsPerUnit;
  final String sourceItemId;
  final String sourceName;

  const PortionOption({
    required this.unit,
    required this.gramsPerUnit,
    required this.sourceItemId,
    required this.sourceName,
  });

  factory PortionOption.fromJson(Map<String, dynamic> json) => PortionOption(
        unit: _requiredString(json, 'unit'),
        gramsPerUnit: _positive(json['grams_per_unit'], 'grams_per_unit'),
        sourceItemId: _requiredString(json, 'source_item_id'),
        sourceName: _requiredString(json, 'source_name'),
      );

  Map<String, dynamic> toJson() => {
        'unit': unit,
        'grams_per_unit': gramsPerUnit,
        'source_item_id': sourceItemId,
        'source_name': sourceName,
      };
}

/// POST /api/v1/analyze-food yanıtı
class FoodAnalysisResult {
  final String analysisId;
  final String? logId;
  final String foodName;
  final String foodNameTr;
  final String canonicalFoodId;
  final String normalizationVersion;
  final double caloriesPer100g;
  final double portionGrams;
  final double portionValue;
  final String portionUnit;
  final String portionMethod;
  final bool portionIsEstimate;
  final double totalCalories;
  final double confidence;
  final NutrientData nutrients;
  final String mealType;
  final String recognitionSource;
  final String nutritionSource;
  final String nutritionStatus;
  final String nutritionReliability;
  final NutritionProvenance? provenance;
  final List<PortionOption> portionOptions;
  final double macroCalories;
  final double macroCalorieDelta;
  final double macroCalorieDeltaPercent;
  final List<FoodCandidate> candidates;
  final bool needsConfirmation;
  final bool canConfirm;
  final String ttsText;

  const FoodAnalysisResult({
    required this.analysisId,
    this.logId,
    required this.foodName,
    required this.foodNameTr,
    required this.canonicalFoodId,
    required this.normalizationVersion,
    required this.caloriesPer100g,
    required this.portionGrams,
    required this.portionValue,
    required this.portionUnit,
    required this.portionMethod,
    required this.portionIsEstimate,
    required this.totalCalories,
    required this.confidence,
    required this.nutrients,
    required this.mealType,
    required this.recognitionSource,
    required this.nutritionSource,
    required this.nutritionStatus,
    required this.nutritionReliability,
    required this.provenance,
    required this.portionOptions,
    required this.macroCalories,
    required this.macroCalorieDelta,
    required this.macroCalorieDeltaPercent,
    required this.candidates,
    required this.needsConfirmation,
    required this.canConfirm,
    required this.ttsText,
  });

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    return FoodAnalysisResult(
      analysisId: _requiredString(json, 'analysis_id'),
      logId: json['log_id'] as String?,
      foodName: _requiredString(json, 'food_name'),
      foodNameTr: _requiredString(json, 'food_name_tr'),
      canonicalFoodId: _requiredString(json, 'canonical_food_id'),
      normalizationVersion: _requiredString(json, 'normalization_version'),
      caloriesPer100g:
          _nonNegativeOrZero(json['calories_per_100g'], 'calories_per_100g'),
      portionGrams: _nonNegativeOrZero(json['portion_grams'], 'portion_grams'),
      portionValue: _nonNegativeOrZero(json['portion_value'], 'portion_value'),
      portionUnit: json['portion_unit'] as String? ?? '',
      portionMethod: json['portion_method'] as String? ?? '',
      portionIsEstimate: json['portion_is_estimate'] as bool? ?? true,
      totalCalories:
          _nonNegativeOrZero(json['total_calories'], 'total_calories'),
      confidence: _confidence(json['confidence']),
      nutrients: NutrientData.fromJson(_mapOrEmpty(json['nutrients'])),
      mealType: json['meal_type'] ?? 'atistirmalik',
      recognitionSource: json['recognition_source'] as String? ?? 'unknown',
      nutritionSource: json['nutrition_source'] as String? ?? 'unknown',
      nutritionStatus: json['nutrition_status'] as String? ?? 'not_found',
      nutritionReliability:
          json['nutrition_reliability'] as String? ?? 'not_found',
      provenance: json['provenance'] is Map<String, dynamic>
          ? NutritionProvenance.fromJson(
              json['provenance'] as Map<String, dynamic>)
          : null,
      portionOptions: (json['portion_options'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PortionOption.fromJson)
          .toList(growable: false),
      macroCalories:
          _nonNegativeOrZero(json['macro_calories'], 'macro_calories'),
      macroCalorieDelta:
          _finiteOrZero(json['macro_calorie_delta'], 'macro_calorie_delta'),
      macroCalorieDeltaPercent: _nonNegativeOrZero(
          json['macro_calorie_delta_percent'], 'macro_calorie_delta_percent'),
      candidates: (json['candidates'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .take(3)
          .map(FoodCandidate.fromJson)
          .toList(growable: false),
      needsConfirmation: json['needs_confirmation'] as bool? ?? true,
      canConfirm: json['can_confirm'] as bool? ?? false,
      ttsText: json['tts_text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'analysis_id': analysisId,
        'log_id': logId,
        'food_name': foodName,
        'food_name_tr': foodNameTr,
        'canonical_food_id': canonicalFoodId,
        'normalization_version': normalizationVersion,
        'calories_per_100g': caloriesPer100g,
        'portion_grams': portionGrams,
        'portion_value': portionValue,
        'portion_unit': portionUnit,
        'portion_method': portionMethod,
        'portion_is_estimate': portionIsEstimate,
        'total_calories': totalCalories,
        'confidence': confidence,
        'nutrients': nutrients.toJson(),
        'meal_type': mealType,
        'recognition_source': recognitionSource,
        'nutrition_source': nutritionSource,
        'nutrition_status': nutritionStatus,
        'nutrition_reliability': nutritionReliability,
        'provenance': provenance?.toJson(),
        'portion_options':
            portionOptions.map((option) => option.toJson()).toList(),
        'macro_calories': macroCalories,
        'macro_calorie_delta': macroCalorieDelta,
        'macro_calorie_delta_percent': macroCalorieDeltaPercent,
        'candidates': candidates
            .map((candidate) => {
                  'food_name': candidate.foodName,
                  'food_name_tr': candidate.foodNameTr,
                  'confidence': candidate.confidence,
                })
            .toList(growable: false),
        'needs_confirmation': needsConfirmation,
        'can_confirm': canConfirm,
        'tts_text': ttsText,
      };
}

class FoodAnalysisDecisionResult {
  final String analysisId;
  final String? logId;
  final String status;
  final String message;

  const FoodAnalysisDecisionResult({
    required this.analysisId,
    required this.logId,
    required this.status,
    required this.message,
  });

  factory FoodAnalysisDecisionResult.fromJson(Map<String, dynamic> json) =>
      FoodAnalysisDecisionResult(
        analysisId: _requiredString(json, 'analysis_id'),
        logId: json['log_id'] as String?,
        status: _requiredString(json, 'status'),
        message: _requiredString(json, 'message'),
      );
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

double _finiteOrZero(dynamic value, String field) {
  if (value == null) return 0;
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('$field sonlu bir sayı olmalıdır');
  }
  return value.toDouble();
}

double _nonNegativeOrZero(dynamic value, String field) {
  final result = _finiteOrZero(value, field);
  if (result < 0) throw FormatException('$field negatif olamaz');
  return result;
}

double _positive(dynamic value, String field) {
  final result = _finiteOrZero(value, field);
  if (result <= 0) throw FormatException('$field sıfırdan büyük olmalıdır');
  return result;
}

/// Yemek geçmişi — tek besin kaydı
class FoodLogEntry {
  final String id;
  final String foodName;
  final String foodNameTr;
  final String canonicalFoodId;
  final double calories;
  final double caloriesPer100g;
  final double portionG;
  final double portionValue;
  final String portionUnit;
  final String portionMethod;
  final bool portionIsEstimate;
  final String mealType;
  final double confidence;
  final String recognitionSource;
  final String nutritionSource;
  final String nutritionReliability;
  final bool isCorrected;
  final bool isUserConfirmed;
  final NutrientData nutrients;
  final DateTime loggedAt;
  final DateTime updatedAt;

  const FoodLogEntry({
    required this.id,
    required this.foodName,
    required this.foodNameTr,
    required this.canonicalFoodId,
    required this.calories,
    required this.caloriesPer100g,
    required this.portionG,
    required this.portionValue,
    required this.portionUnit,
    required this.portionMethod,
    required this.portionIsEstimate,
    required this.mealType,
    required this.confidence,
    required this.recognitionSource,
    required this.nutritionSource,
    required this.nutritionReliability,
    required this.isCorrected,
    required this.isUserConfirmed,
    required this.nutrients,
    required this.loggedAt,
    required this.updatedAt,
  });

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) {
    return FoodLogEntry(
      id: json['id'] ?? '',
      foodName: json['food_name'] ?? '',
      foodNameTr: json['food_name_tr'] ?? '',
      canonicalFoodId: json['canonical_food_id'] ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      caloriesPer100g: (json['calories_per_100g'] as num?)?.toDouble() ?? 0,
      portionG: (json['portion_g'] as num?)?.toDouble() ?? 0,
      portionValue: (json['portion_value'] as num?)?.toDouble() ??
          (json['portion_g'] as num?)?.toDouble() ??
          0,
      portionUnit: json['portion_unit'] ?? 'gram',
      portionMethod: json['portion_method'] ?? 'legacy_unknown',
      portionIsEstimate: json['portion_is_estimate'] ?? true,
      mealType: json['meal_type'] ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      recognitionSource: json['recognition_source'] ?? 'unavailable',
      nutritionSource: json['nutrition_source'] ?? 'unavailable',
      nutritionReliability: json['nutrition_reliability'] ?? 'unverified',
      isCorrected: json['is_corrected'] ?? false,
      isUserConfirmed: json['is_user_confirmed'] ?? false,
      nutrients: NutrientData.fromJson(_mapOrEmpty(json['nutrients'])),
      loggedAt: DateTime.tryParse(json['logged_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ??
          DateTime.tryParse(json['logged_at'] ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'food_name': foodName,
        'food_name_tr': foodNameTr,
        'canonical_food_id': canonicalFoodId,
        'calories': calories,
        'calories_per_100g': caloriesPer100g,
        'portion_g': portionG,
        'portion_value': portionValue,
        'portion_unit': portionUnit,
        'portion_method': portionMethod,
        'portion_is_estimate': portionIsEstimate,
        'meal_type': mealType,
        'confidence': confidence,
        'recognition_source': recognitionSource,
        'nutrition_source': nutritionSource,
        'nutrition_reliability': nutritionReliability,
        'is_corrected': isCorrected,
        'is_user_confirmed': isUserConfirmed,
        'nutrients': nutrients.toJson(),
        'logged_at': loggedAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  String get mealTypeTr => switch (mealType) {
        'kahvalti' => 'Kahvaltı',
        'ogle' => 'Öğle',
        'aksam' => 'Akşam',
        _ => 'Atıştırmalık',
      };

  String get recognitionSourceTr => switch (recognitionSource) {
        'google_vision' => 'çevrim içi görüntü tanıma',
        'tflite' => 'çevrim dışı cihaz modeli',
        'manual' => 'kullanıcı girişi',
        _ => 'kaynak belirtilmemiş',
      };

  String get statusLabel => isCorrected
      ? 'Düzeltilmiş'
      : portionIsEstimate
          ? 'Tahmini porsiyon'
          : 'Kullanıcı onaylı';

  String get portionLabel => portionUnit == 'gram'
      ? '${portionG.toStringAsFixed(0)} gram'
      : '${portionValue.toStringAsFixed(0)} $portionUnit';

  DateTime get localLoggedAt => loggedAt.toLocal();

  String get localDateTimeLabel {
    final local = localLoggedAt;
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.${local.year}, '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String get semanticLabel => '$foodNameTr, $portionLabel, '
      '${calories.toStringAsFixed(0)} kalori, '
      '${nutrients.protein.toStringAsFixed(1)} gram protein, '
      '${nutrients.carbs.toStringAsFixed(1)} gram karbonhidrat, '
      '${nutrients.fat.toStringAsFixed(1)} gram yağ, '
      '$mealTypeTr öğünü, $localDateTimeLabel, '
      '$recognitionSourceTr, $statusLabel.';
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

  Map<String, dynamic> toJson() => {
        'meal_type': mealType,
        'meal_type_tr': mealTypeTr,
        'total_calories': totalCalories,
        'food_count': foodCount,
      };
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

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().split('T').first,
        'total_calories': totalCalories,
        'calorie_target': calorieTarget,
        'remaining_calories': remainingCalories,
        'total_protein': totalProtein,
        'total_carbs': totalCarbs,
        'total_fat': totalFat,
        'meal_count': mealCount,
        'meals': meals.map((meal) => meal.toJson()).toList(),
        'foods': foods.map((food) => food.toJson()).toList(),
      };
}

/// GET /api/v1/food-history yanıtı
class FoodHistoryResult {
  final String userId;
  final DateTime fromDate;
  final DateTime toDate;
  final int totalDays;
  final double averageDailyCalories;
  final double totalCalories;
  final int totalLogCount;
  final int totalDateCount;
  final int page;
  final int pageSize;
  final bool hasMore;
  final List<DailyLog> dailyLogs;

  const FoodHistoryResult({
    required this.userId,
    required this.fromDate,
    required this.toDate,
    required this.totalDays,
    required this.averageDailyCalories,
    required this.totalCalories,
    required this.totalLogCount,
    required this.totalDateCount,
    required this.page,
    required this.pageSize,
    required this.hasMore,
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
      totalLogCount: json['total_log_count'] ?? 0,
      totalDateCount: json['total_date_count'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 7,
      hasMore: json['has_more'] ?? false,
      dailyLogs: (json['daily_logs'] as List?)
              ?.map((d) => DailyLog.fromJson(d))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'from_date': fromDate.toIso8601String().split('T').first,
        'to_date': toDate.toIso8601String().split('T').first,
        'total_days': totalDays,
        'average_daily_calories': averageDailyCalories,
        'total_calories': totalCalories,
        'total_log_count': totalLogCount,
        'total_date_count': totalDateCount,
        'page': page,
        'page_size': pageSize,
        'has_more': hasMore,
        'daily_logs': dailyLogs.map((day) => day.toJson()).toList(),
      };
}

/// POST /api/v1/send-to-dietitian yanıtı
class SendToDietitianResult {
  final bool success;
  final String reportId;
  final bool sentViaEmail;
  final bool sentViaSms;
  final String dietitianName;
  final String status;
  final List<ChannelDeliveryResult> channels;
  final bool duplicate;
  final String message;

  const SendToDietitianResult({
    required this.success,
    required this.reportId,
    required this.sentViaEmail,
    required this.sentViaSms,
    required this.dietitianName,
    required this.status,
    required this.channels,
    required this.duplicate,
    required this.message,
  });

  factory SendToDietitianResult.fromJson(Map<String, dynamic> json) {
    return SendToDietitianResult(
      success: json['success'] ?? false,
      reportId: json['report_id'] ?? '',
      sentViaEmail: json['sent_via_email'] ?? false,
      sentViaSms: json['sent_via_sms'] ?? false,
      dietitianName: json['dietitian_name'] ?? '',
      status: json['status'] ?? 'failed',
      channels: (json['channels'] as List? ?? const [])
          .map((item) => ChannelDeliveryResult.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      duplicate: json['duplicate'] ?? false,
      message: json['message'] ?? '',
    );
  }
}

class ChannelDeliveryResult {
  const ChannelDeliveryResult({
    required this.channel,
    required this.status,
    required this.destinationMasked,
    required this.attemptCount,
    required this.maxAttempts,
    this.providerStatus,
    this.errorCode,
  });

  final String channel;
  final String status;
  final String destinationMasked;
  final int attemptCount;
  final int maxAttempts;
  final String? providerStatus;
  final String? errorCode;

  bool get isSent => status == 'sent';
  bool get canRetry => status == 'failed' && attemptCount < maxAttempts;
  String get channelLabel => channel == 'email' ? 'E-posta' : 'SMS';

  factory ChannelDeliveryResult.fromJson(Map<String, dynamic> json) =>
      ChannelDeliveryResult(
        channel: json['channel'] ?? '',
        status: json['status'] ?? 'failed',
        destinationMasked: json['destination_masked'] ?? '***',
        attemptCount: json['attempt_count'] ?? 0,
        maxAttempts: json['max_attempts'] ?? 3,
        providerStatus: json['provider_status'],
        errorCode: json['error_code'],
      );
}

class DietitianReportPreview {
  const DietitianReportPreview({
    required this.reportType,
    required this.fromDate,
    required this.toDate,
    required this.recordCount,
    required this.totalCalories,
    required this.averageDailyCalories,
    required this.estimatedPortionCount,
    required this.dietitianName,
    required this.recipients,
    required this.channels,
    required this.consentContextHash,
    required this.accessibilitySummary,
  });

  final String reportType;
  final DateTime fromDate;
  final DateTime toDate;
  final int recordCount;
  final double totalCalories;
  final double averageDailyCalories;
  final int estimatedPortionCount;
  final String dietitianName;
  final Map<String, String> recipients;
  final List<String> channels;
  final String consentContextHash;
  final String accessibilitySummary;

  factory DietitianReportPreview.fromJson(Map<String, dynamic> json) =>
      DietitianReportPreview(
        reportType: json['report_type'] ?? '',
        fromDate: DateTime.parse(json['from_date']),
        toDate: DateTime.parse(json['to_date']),
        recordCount: json['record_count'] ?? 0,
        totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
        averageDailyCalories:
            (json['average_daily_calories'] as num?)?.toDouble() ?? 0,
        estimatedPortionCount: json['estimated_portion_count'] ?? 0,
        dietitianName: json['dietitian_name'] ?? '',
        recipients: Map<String, String>.from(json['recipients'] ?? const {}),
        channels: List<String>.from(json['channels'] ?? const []),
        consentContextHash: json['consent_context_hash'] ?? '',
        accessibilitySummary: json['accessibility_summary'] ?? '',
      );
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
