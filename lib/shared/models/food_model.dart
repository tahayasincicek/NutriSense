// =============================================================================
// lib/shared/models/food_model.dart
// NutriSense — Besin Veri Modelleri
// =============================================================================

import 'package:equatable/equatable.dart';

/// Besin modeli — veritabanındaki foods tablosuna karşılık gelir
class FoodModel extends Equatable {
  final int id;
  final String name;
  final String? nameEn;
  final int? categoryId;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double defaultPortionG;
  final String? imageUrl;
  final bool isVerified;

  const FoodModel({
    required this.id,
    required this.name,
    this.nameEn,
    this.categoryId,
    required this.caloriesPer100g,
    this.proteinPer100g = 0,
    this.carbsPer100g = 0,
    this.fatPer100g = 0,
    this.fiberPer100g = 0,
    this.defaultPortionG = 100,
    this.imageUrl,
    this.isVerified = false,
  });

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    return FoodModel(
      id: json['food_id'] as int,
      name: json['name'] as String? ?? json['food_name'] as String,
      nameEn: json['name_en'] as String?,
      categoryId: json['category_id'] as int?,
      caloriesPer100g: (json['calories_per_100g'] as num?)?.toDouble() ?? 0,
      proteinPer100g: (json['protein_per_100g'] as num?)?.toDouble() ?? 0,
      carbsPer100g: (json['carbs_per_100g'] as num?)?.toDouble() ?? 0,
      fatPer100g: (json['fat_per_100g'] as num?)?.toDouble() ?? 0,
      fiberPer100g: (json['fiber_per_100g'] as num?)?.toDouble() ?? 0,
      defaultPortionG: (json['default_portion_g'] as num?)?.toDouble() ?? 100,
      imageUrl: json['image_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'food_id': id,
        'name': name,
        'name_en': nameEn,
        'category_id': categoryId,
        'calories_per_100g': caloriesPer100g,
        'protein_per_100g': proteinPer100g,
        'carbs_per_100g': carbsPer100g,
        'fat_per_100g': fatPer100g,
        'fiber_per_100g': fiberPer100g,
        'default_portion_g': defaultPortionG,
        'image_url': imageUrl,
        'is_verified': isVerified,
      };

  /// Belirtilen porsiyon için kalori hesaplar
  double caloriesForPortion(double grams) => (grams / 100) * caloriesPer100g;

  /// Belirtilen porsiyon için besin değerlerini hesaplar
  NutrientInfo nutrientsForPortion(double grams) {
    final factor = grams / 100;
    return NutrientInfo(
      calories: caloriesPer100g * factor,
      protein: proteinPer100g * factor,
      carbs: carbsPer100g * factor,
      fat: fatPer100g * factor,
      fiber: fiberPer100g * factor,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

/// Besin değerleri
class NutrientInfo extends Equatable {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const NutrientInfo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });

  @override
  List<Object?> get props => [calories, protein, carbs, fat, fiber];
}

/// Besin tanıma sonucu — AI modelden gelen sonuç
class FoodRecognitionResult extends Equatable {
  final int? foodId;
  final String foodName;
  final String? foodNameEn;
  final double confidence;
  final double portionGrams;
  final double calories;
  final NutrientInfo? nutrients;
  final String? mealType;
  final DateTime timestamp;

  const FoodRecognitionResult({
    this.foodId,
    required this.foodName,
    this.foodNameEn,
    required this.confidence,
    required this.portionGrams,
    required this.calories,
    this.nutrients,
    this.mealType,
    required this.timestamp,
  });

  factory FoodRecognitionResult.fromJson(Map<String, dynamic> json) {
    final nutrients = json['nutrients'] as Map<String, dynamic>?;
    return FoodRecognitionResult(
      foodId: json['food_id'] as int?,
      foodName: json['food_name'] as String,
      foodNameEn: json['food_name_en'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      portionGrams: (json['portion_grams'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      nutrients: nutrients != null
          ? NutrientInfo(
              calories: (json['calories'] as num).toDouble(),
              protein: (nutrients['protein'] as num?)?.toDouble() ?? 0,
              carbs: (nutrients['carbs'] as num?)?.toDouble() ?? 0,
              fat: (nutrients['fat'] as num?)?.toDouble() ?? 0,
              fiber: (nutrients['fiber'] as num?)?.toDouble() ?? 0,
            )
          : null,
      mealType: json['meal_type'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Güvenilirlik durumu kontrolü
  bool get isHighConfidence => confidence >= 0.85;
  bool get isMediumConfidence => confidence >= 0.60 && confidence < 0.85;
  bool get isLowConfidence => confidence < 0.60;

  /// TTS için okunacak metin
  String toSpeechText() {
    final buffer = StringBuffer();
    buffer.write('$foodName tanındı. ');
    buffer.write('${portionGrams.toStringAsFixed(0)} gram, ');
    buffer.write('${calories.toStringAsFixed(0)} kalori.');

    if (nutrients != null) {
      buffer.write(' ${nutrients!.protein.toStringAsFixed(0)} gram protein,');
      buffer
          .write(' ${nutrients!.carbs.toStringAsFixed(0)} gram karbonhidrat,');
      buffer.write(' ${nutrients!.fat.toStringAsFixed(0)} gram yağ.');
    }

    return buffer.toString();
  }

  @override
  List<Object?> get props =>
      [foodId, foodName, confidence, portionGrams, calories];
}

/// Yemek günlüğü kaydı — food_logs tablosuna karşılık gelir
class FoodLogEntry extends Equatable {
  final int? id;
  final int userId;
  final int? foodId;
  final String foodName;
  final String? imageUrl;
  final double? confidence;
  final double portionGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String mealType;
  final String inputMethod; // 'camera', 'voice', 'manual'
  final DateTime loggedAt;

  const FoodLogEntry({
    this.id,
    required this.userId,
    this.foodId,
    required this.foodName,
    this.imageUrl,
    this.confidence,
    required this.portionGrams,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    required this.mealType,
    this.inputMethod = 'camera',
    required this.loggedAt,
  });

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) {
    return FoodLogEntry(
      id: json['log_id'] as int?,
      userId: json['user_id'] as int? ?? 0,
      foodId: json['food_id'] as int?,
      foodName: json['food_name'] as String,
      imageUrl: json['image_url'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      portionGrams: (json['portion_grams'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      mealType: json['meal_type'] as String,
      inputMethod: json['input_method'] as String? ?? 'camera',
      loggedAt: DateTime.parse(
          json['logged_at'] as String? ?? json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'food_id': foodId,
        'food_name': foodName,
        'portion_grams': portionGrams,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'meal_type': mealType,
        'input_method': inputMethod,
      };

  /// Ekran okuyucu için özet metin
  String toAccessibleSummary() {
    return '$foodName, ${calories.toStringAsFixed(0)} kalori, '
        '${portionGrams.toStringAsFixed(0)} gram';
  }

  @override
  List<Object?> get props => [id, foodName, calories, loggedAt];
}
