// =============================================================================
// test/unit/food_entry_test.dart
// NutriSense — FoodEntry Model Birim Testleri
//
// JSON serileştirme/deserileştirme, alan tipleri, TTS metni.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/models/food_history_model.dart';

void main() {
  group('MacroBreakdown', () {
    test('fromJson — doğru alanlar', () {
      final json = {'protein': 15.0, 'carb': 30.0, 'fat': 8.0, 'fiber': 3.0};
      final macro = MacroBreakdown.fromJson(json);

      expect(macro.protein, 15.0);
      expect(macro.carb, 30.0);
      expect(macro.fat, 8.0);
      expect(macro.fiber, 3.0);
    });

    test('fromJson — eksik alanlar varsayılan 0', () {
      final macro = MacroBreakdown.fromJson({});
      expect(macro.protein, 0);
      expect(macro.carb, 0);
      expect(macro.fat, 0);
    });

    test('toJson — gidiş-dönüş', () {
      final original = MacroBreakdown(protein: 20, carb: 40, fat: 12);
      final json = original.toJson();
      final restored = MacroBreakdown.fromJson(json);

      expect(restored.protein, original.protein);
      expect(restored.carb, original.carb);
      expect(restored.fat, original.fat);
    });

    test('yüzde hesaplama', () {
      final macro = MacroBreakdown(protein: 25, carb: 50, fat: 25);
      expect(macro.proteinPercent, 25.0);
      expect(macro.carbPercent, 50.0);
      expect(macro.fatPercent, 25.0);
    });

    test('toplam sıfırda yüzde → 0', () {
      final macro = MacroBreakdown();
      expect(macro.proteinPercent, 0);
    });

    test('ttsText — Türkçe format', () {
      final macro = MacroBreakdown(protein: 20, carb: 45, fat: 12);
      expect(macro.ttsText, contains('20 gram protein'));
      expect(macro.ttsText, contains('45 gram karbonhidrat'));
      expect(macro.ttsText, contains('12 gram yağ'));
    });
  });

  group('MealType', () {
    test('fromString — bilinen değerler', () {
      expect(MealType.fromString('kahvalti'), MealType.kahvalti);
      expect(MealType.fromString('ogle'), MealType.ogle);
      expect(MealType.fromString('aksam'), MealType.aksam);
    });

    test('fromString — bilinmeyen değer → atistirmalik', () {
      expect(MealType.fromString('bilinmeyen'), MealType.atistirmalik);
      expect(MealType.fromString(''), MealType.atistirmalik);
    });

    test('displayName — Türkçe', () {
      expect(MealType.kahvalti.displayName, 'Kahvaltı');
      expect(MealType.ogle.displayName, 'Öğle');
      expect(MealType.aksam.displayName, 'Akşam');
    });
  });

  group('FoodEntry', () {
    final sampleJson = {
      'id': 'test-001',
      'food_name': 'Apple',
      'food_name_tr': 'Elma',
      'calories_per_100g': 52.0,
      'portion_g': 150.0,
      'total_calories': 78.0,
      'meal_type': 'kahvalti',
      'scanned_at': '2026-03-16T10:30:00.000',
      'image_url': null,
      'nutrients': {'protein': 0.3, 'carb': 14.0, 'fat': 0.2},
      'confidence': 0.95,
      'source': 'google_vision',
    };

    test('fromJson — tüm alanlar doğru', () {
      final entry = FoodEntry.fromJson(sampleJson);

      expect(entry.id, 'test-001');
      expect(entry.foodName, 'Apple');
      expect(entry.foodNameTr, 'Elma');
      expect(entry.caloriesPer100g, 52.0);
      expect(entry.portionGrams, 150.0);
      expect(entry.totalCalories, 78.0);
      expect(entry.mealType, MealType.kahvalti);
      expect(entry.confidence, 0.95);
      expect(entry.source, 'google_vision');
    });

    test('fromJson — eksik alanlar varsayılan', () {
      final entry = FoodEntry.fromJson({'id': 'x'});

      expect(entry.foodName, '');
      expect(entry.caloriesPer100g, 0);
      expect(entry.portionGrams, 100); // varsayılan 100g
      expect(entry.totalCalories, 0);
    });

    test('toJson → fromJson gidiş-dönüş', () {
      final original = FoodEntry.fromJson(sampleJson);
      final json = original.toJson();
      final restored = FoodEntry.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.foodName, original.foodName);
      expect(restored.totalCalories, original.totalCalories);
      expect(restored.mealType, original.mealType);
    });

    test('ttsText — Türkçe sesli okuma', () {
      final entry = FoodEntry.fromJson(sampleJson);

      expect(entry.ttsText, contains('Elma'));
      expect(entry.ttsText, contains('150 gram'));
      expect(entry.ttsText, contains('78 kalori'));
      expect(entry.ttsText, contains('Kahvaltı'));
    });

    test('timeText — saat formatı', () {
      final entry = FoodEntry.fromJson(sampleJson);
      expect(entry.timeText, '10:30');
    });
  });

  group('DailyNutrition', () {
    test('hesaplanan alanlar doğru', () {
      final day = DailyNutrition(
        date: DateTime(2026, 3, 16),
        totalCalories: 1500,
        targetCalories: 2000,
        entries: [],
        macroBreakdown: MacroBreakdown(protein: 60, carb: 200, fat: 50),
      );

      expect(day.targetPercent, 75.0);
      expect(day.remaining, 500.0);
      expect(day.mealCount, 0);
    });

    test('hedef aşıldığında remaining negatif', () {
      final day = DailyNutrition(
        date: DateTime(2026, 3, 16),
        totalCalories: 2500,
        targetCalories: 2000,
        entries: [],
        macroBreakdown: MacroBreakdown(),
      );

      expect(day.remaining, -500.0);
      expect(day.targetPercent, 125.0);
    });

    test('dateTr — Türkçe tarih formatı', () {
      final day = DailyNutrition(
        date: DateTime(2026, 3, 16),
        totalCalories: 0,
        entries: [],
        macroBreakdown: MacroBreakdown(),
      );

      expect(day.dateTr, '16 Mart 2026');
    });

    test('ttsText — sesli özet', () {
      final day = DailyNutrition(
        date: DateTime(2026, 3, 16),
        totalCalories: 1800,
        targetCalories: 2000,
        entries: [
          FoodEntry.fromJson({
            'id': '1',
            'food_name_tr': 'Elma',
            'total_calories': 78,
            'meal_type': 'kahvalti',
          }),
        ],
        macroBreakdown: MacroBreakdown(),
      );

      expect(day.ttsText, contains('1800 kalori'));
      expect(day.ttsText, contains('1 öğün'));
    });
  });

  group('WeeklyReport', () {
    test('topFoods — en çok yenen besinler', () {
      final days = [
        DailyNutrition(
          date: DateTime(2026, 3, 16),
          totalCalories: 1500,
          entries: [
            FoodEntry.fromJson(
                {'id': '1', 'food_name_tr': 'Elma', 'total_calories': 78}),
            FoodEntry.fromJson(
                {'id': '2', 'food_name_tr': 'Elma', 'total_calories': 78}),
            FoodEntry.fromJson(
                {'id': '3', 'food_name_tr': 'Pilav', 'total_calories': 195}),
          ],
          macroBreakdown: MacroBreakdown(),
        ),
      ];

      final report = WeeklyReport(
        startDate: DateTime(2026, 3, 10),
        endDate: DateTime(2026, 3, 16),
        dailySummaries: days,
        averageCalories: 1500,
        averageMacros: MacroBreakdown(),
      );

      expect(report.topFoods.first.key, 'Elma');
      expect(report.topFoods.first.value, 2);
    });
  });
}
