// =============================================================================
// lib/shared/models/food_history_model.dart
// NutriSense — Besin Geçmişi Veri Modelleri
//
// FoodEntry, DailyNutrition, WeeklyReport sınıfları.
// Tüm modeller fromJson/toJson serileştirme destekler.
// =============================================================================

/// Makro besin dağılımı
class MacroBreakdown {
  final double protein;
  final double carb;
  final double fat;
  final double fiber;

  const MacroBreakdown({
    this.protein = 0,
    this.carb = 0,
    this.fat = 0,
    this.fiber = 0,
  });

  factory MacroBreakdown.fromJson(Map<String, dynamic> json) => MacroBreakdown(
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carb: (json['carb'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'protein': protein,
        'carb': carb,
        'fat': fat,
        'fiber': fiber,
      };

  /// Toplam gram
  double get total => protein + carb + fat;

  /// Yüzde dağılımı
  double get proteinPercent => total > 0 ? (protein / total) * 100 : 0;
  double get carbPercent => total > 0 ? (carb / total) * 100 : 0;
  double get fatPercent => total > 0 ? (fat / total) * 100 : 0;

  /// TTS metni
  String get ttsText => '${protein.toStringAsFixed(0)} gram protein, '
      '${carb.toStringAsFixed(0)} gram karbonhidrat, '
      '${fat.toStringAsFixed(0)} gram yağ.';
}

// ═══════════════════════════════════════════════════════════════════════════════
// BESİN KAYDI
// ═══════════════════════════════════════════════════════════════════════════════

/// Öğün türleri
enum MealType {
  kahvalti('Kahvaltı', 'kahvalti'),
  ogle('Öğle', 'ogle'),
  aksam('Akşam', 'aksam'),
  atistirmalik('Atıştırmalık', 'atistirmalik');

  const MealType(this.displayName, this.apiValue);
  final String displayName;
  final String apiValue;

  static MealType fromString(String value) {
    return MealType.values.firstWhere(
      (e) => e.apiValue == value || e.name == value,
      orElse: () => MealType.atistirmalik,
    );
  }
}

/// Tek besin kaydı
class FoodEntry {
  final String id;
  final String foodName;
  final String foodNameTr;
  final double caloriesPer100g;
  final double portionGrams;
  final double totalCalories;
  final MealType mealType;
  final DateTime scannedAt;
  final String? imageUrl;
  final MacroBreakdown nutrients;
  final double confidence;
  final String source; // google_vision | tflite | manual

  const FoodEntry({
    required this.id,
    required this.foodName,
    required this.foodNameTr,
    required this.caloriesPer100g,
    required this.portionGrams,
    required this.totalCalories,
    required this.mealType,
    required this.scannedAt,
    this.imageUrl,
    required this.nutrients,
    this.confidence = 0,
    this.source = 'google_vision',
  });

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
        id: json['id'] ?? '',
        foodName: json['food_name'] ?? '',
        foodNameTr: json['food_name_tr'] ?? json['food_name'] ?? '',
        caloriesPer100g: (json['calories_per_100g'] as num?)?.toDouble() ?? 0,
        portionGrams: (json['portion_g'] as num?)?.toDouble() ??
            (json['estimated_portion_g'] as num?)?.toDouble() ??
            100,
        totalCalories: (json['total_calories'] as num?)?.toDouble() ??
            (json['calories'] as num?)?.toDouble() ??
            0,
        mealType: MealType.fromString(json['meal_type'] ?? ''),
        scannedAt:
            DateTime.tryParse(json['logged_at'] ?? json['scanned_at'] ?? '') ??
                DateTime.now(),
        imageUrl: json['image_url'],
        nutrients: MacroBreakdown.fromJson(json['nutrients'] ?? {}),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        source: json['recognition_source'] ?? json['source'] ?? 'google_vision',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'food_name': foodName,
        'food_name_tr': foodNameTr,
        'calories_per_100g': caloriesPer100g,
        'portion_g': portionGrams,
        'total_calories': totalCalories,
        'meal_type': mealType.apiValue,
        'scanned_at': scannedAt.toIso8601String(),
        'image_url': imageUrl,
        'nutrients': nutrients.toJson(),
        'confidence': confidence,
        'source': source,
      };

  /// TTS okuma metni
  String get ttsText => '$foodNameTr, ${portionGrams.toStringAsFixed(0)} gram, '
      '${totalCalories.toStringAsFixed(0)} kalori. '
      '${mealType.displayName} öğünü.';

  /// Saat bilgisi formatı
  String get timeText => '${scannedAt.hour.toString().padLeft(2, '0')}:'
      '${scannedAt.minute.toString().padLeft(2, '0')}';
}

// ═══════════════════════════════════════════════════════════════════════════════
// GÜNLÜK BESİN ÖZETİ
// ═══════════════════════════════════════════════════════════════════════════════

/// Bir günlük besin tüketim özeti
class DailyNutrition {
  final DateTime date;
  final double totalCalories;
  final double targetCalories;
  final List<FoodEntry> entries;
  final MacroBreakdown macroBreakdown;

  const DailyNutrition({
    required this.date,
    required this.totalCalories,
    this.targetCalories = 2000,
    required this.entries,
    required this.macroBreakdown,
  });

  factory DailyNutrition.fromJson(Map<String, dynamic> json) {
    final foods =
        (json['foods'] as List?)?.map((f) => FoodEntry.fromJson(f)).toList() ??
            [];

    return DailyNutrition(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
      targetCalories: (json['calorie_target'] as num?)?.toDouble() ?? 2000,
      entries: foods,
      macroBreakdown: MacroBreakdown(
        protein: (json['total_protein'] as num?)?.toDouble() ?? 0,
        carb: (json['total_carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['total_fat'] as num?)?.toDouble() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String().split('T')[0],
        'total_calories': totalCalories,
        'calorie_target': targetCalories,
        'foods': entries.map((e) => e.toJson()).toList(),
        'total_protein': macroBreakdown.protein,
        'total_carbs': macroBreakdown.carb,
        'total_fat': macroBreakdown.fat,
      };

  /// Hedef doluluk yüzdesi
  double get targetPercent =>
      targetCalories > 0 ? (totalCalories / targetCalories) * 100 : 0;

  /// Kalan kalori
  double get remaining => targetCalories - totalCalories;

  /// Öğün sayısı
  int get mealCount => entries.length;

  /// Belirli öğün türündeki yemekler
  List<FoodEntry> entriesByMeal(MealType meal) =>
      entries.where((e) => e.mealType == meal).toList();

  /// Tarih formatı (gg.aa.yyyy)
  String get dateFormatted => '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';

  /// Türkçe tarih
  String get dateTr {
    final months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  /// Sesli özet metni
  String get ttsText {
    final pct = targetPercent.toStringAsFixed(0);
    final buffer = StringBuffer('$dateTr günlük özeti: ');
    buffer
        .write('Toplam ${totalCalories.toStringAsFixed(0)} kalori tüketildi. ');
    buffer.write('$mealCount öğün kaydedildi. ');

    if (remaining > 0) {
      buffer.write('Hedefinizin yüzde $pct\'sine ulaştınız. ');
      buffer.write('${remaining.toStringAsFixed(0)} kalori kaldı.');
    } else {
      buffer.write('Günlük hedefinizi yüzde $pct oranında aştınız.');
    }

    return buffer.toString();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HAFTALIK RAPOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Haftalık besin özet raporu
class WeeklyReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<DailyNutrition> dailySummaries;
  final double averageCalories;
  final double targetCalories;
  final MacroBreakdown averageMacros;

  const WeeklyReport({
    required this.startDate,
    required this.endDate,
    required this.dailySummaries,
    required this.averageCalories,
    this.targetCalories = 2000,
    required this.averageMacros,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    final days = (json['daily_logs'] as List?)
            ?.map((d) => DailyNutrition.fromJson(d))
            .toList() ??
        [];

    return WeeklyReport(
      startDate: DateTime.tryParse(json['from_date'] ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['to_date'] ?? '') ?? DateTime.now(),
      dailySummaries: days,
      averageCalories:
          (json['average_daily_calories'] as num?)?.toDouble() ?? 0,
      targetCalories: (json['calorie_target'] as num?)?.toDouble() ?? 2000,
      averageMacros: MacroBreakdown(
        protein: (json['avg_protein'] as num?)?.toDouble() ?? 0,
        carb: (json['avg_carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['avg_fat'] as num?)?.toDouble() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'from_date': startDate.toIso8601String().split('T')[0],
        'to_date': endDate.toIso8601String().split('T')[0],
        'daily_logs': dailySummaries.map((d) => d.toJson()).toList(),
        'average_daily_calories': averageCalories,
        'calorie_target': targetCalories,
        'avg_protein': averageMacros.protein,
        'avg_carbs': averageMacros.carb,
        'avg_fat': averageMacros.fat,
      };

  /// Toplam gün
  int get totalDays => dailySummaries.length;

  /// Toplam kalori
  double get totalCalories =>
      dailySummaries.fold(0.0, (sum, d) => sum + d.totalCalories);

  /// Toplam öğün
  int get totalMeals => dailySummaries.fold(0, (sum, d) => sum + d.mealCount);

  /// En çok tüketilen 5 besin
  List<MapEntry<String, int>> get topFoods {
    final counts = <String, int>{};
    for (final day in dailySummaries) {
      for (final entry in day.entries) {
        counts[entry.foodNameTr] = (counts[entry.foodNameTr] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  /// TTS özet
  String get ttsText {
    final buffer = StringBuffer('Haftalık rapor özeti. ');
    buffer.write('$totalDays gün, $totalMeals öğün kaydedildi. ');
    buffer.write(
        'Günlük ortalama ${averageCalories.toStringAsFixed(0)} kalori. ');

    if (topFoods.isNotEmpty) {
      buffer.write('En çok tüketilen besin: ${topFoods.first.key}.');
    }

    return buffer.toString();
  }
}
