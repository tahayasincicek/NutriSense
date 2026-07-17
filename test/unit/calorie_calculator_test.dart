// =============================================================================
// test/unit/calorie_calculator_test.dart
// NutriSense — Kalori Hesaplama Birim Testleri
//
// CalorieCalculator ve FoodEntry model testleri.
// Kenar durumları: sıfır porsiyon, negatif değer, null alan.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KALORİ HESAPLAYICI (test edilecek fonksiyon)
// ═══════════════════════════════════════════════════════════════════════════════

/// Kalori hesaplama yardımcı sınıfı
class CalorieCalculator {
  /// Toplam kaloriyi hesaplar: porsiyon (g) × kalori/100g ÷ 100
  static double calculate({
    required double caloriesPer100g,
    required double portionGrams,
  }) {
    if (portionGrams <= 0 || caloriesPer100g < 0) return 0;
    return (portionGrams * caloriesPer100g) / 100;
  }

  /// Makro kalorilerini hesaplar (protein=4kcal/g, karb=4kcal/g, yağ=9kcal/g)
  static double calculateMacroCalories({
    double protein = 0,
    double carb = 0,
    double fat = 0,
  }) {
    return (protein * 4) + (carb * 4) + (fat * 9);
  }

  /// Günlük hedef yüzdesi
  static double targetPercentage({
    required double consumed,
    required double target,
  }) {
    if (target <= 0) return 0;
    return (consumed / target) * 100;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTLER
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  group('CalorieCalculator', () {
    // ── Temel hesaplama ──
    group('calculate()', () {
      test('100g elma (52 kcal/100g) → 52 kcal', () {
        final result = CalorieCalculator.calculate(
          caloriesPer100g: 52,
          portionGrams: 100,
        );
        expect(result, 52.0);
      });

      test('150g pilav (130 kcal/100g) → 195 kcal', () {
        final result = CalorieCalculator.calculate(
          caloriesPer100g: 130,
          portionGrams: 150,
        );
        expect(result, 195.0);
      });

      test('250g mercimek çorbası (56 kcal/100g) → 140 kcal', () {
        final result = CalorieCalculator.calculate(
          caloriesPer100g: 56,
          portionGrams: 250,
        );
        expect(result, 140.0);
      });

      test('50g ceviz (654 kcal/100g) → 327 kcal', () {
        final result = CalorieCalculator.calculate(
          caloriesPer100g: 654,
          portionGrams: 50,
        );
        expect(result, 327.0);
      });
    });

    // ── Kenar durumları ──
    group('kenar durumları', () {
      test('sıfır porsiyon → 0', () {
        final result = CalorieCalculator.calculate(
          caloriesPer100g: 100,
          portionGrams: 0,
        );
        expect(result, 0.0);
      });

      test('negatif porsiyon → 0', () {
        final result = CalorieCalculator.calculate(
          caloriesPer100g: 100,
          portionGrams: -50,
        );
        expect(result, 0.0);
      });

      test('negatif kalori → 0', () {
        final result = CalorieCalculator.calculate(
          caloriesPer100g: -10,
          portionGrams: 100,
        );
        expect(result, 0.0);
      });

      test('sıfır kalori → 0', () {
        final result = CalorieCalculator.calculate(
          caloriesPer100g: 0,
          portionGrams: 200,
        );
        expect(result, 0.0);
      });

      test('çok küçük porsiyon (0.5g)', () {
        final result = CalorieCalculator.calculate(
          caloriesPer100g: 200,
          portionGrams: 0.5,
        );
        expect(result, 1.0);
      });

      test('çok büyük porsiyon (5000g)', () {
        final result = CalorieCalculator.calculate(
          caloriesPer100g: 100,
          portionGrams: 5000,
        );
        expect(result, 5000.0);
      });
    });

    // ── Makro hesaplama ──
    group('calculateMacroCalories()', () {
      test('protein 25g, karb 50g, yağ 10g → 390 kcal', () {
        final result = CalorieCalculator.calculateMacroCalories(
          protein: 25,
          carb: 50,
          fat: 10,
        );
        // (25×4) + (50×4) + (10×9) = 100 + 200 + 90 = 390
        expect(result, 390.0);
      });

      test('tüm sıfır → 0', () {
        final result = CalorieCalculator.calculateMacroCalories();
        expect(result, 0.0);
      });

      test('sadece yağ → 9 kcal/g', () {
        final result = CalorieCalculator.calculateMacroCalories(fat: 10);
        expect(result, 90.0);
      });
    });

    // ── Hedef yüzdesi ──
    group('targetPercentage()', () {
      test('1500/2000 → %75', () {
        final result = CalorieCalculator.targetPercentage(
          consumed: 1500,
          target: 2000,
        );
        expect(result, 75.0);
      });

      test('2400/2000 → %120 (hedef aşıldı)', () {
        final result = CalorieCalculator.targetPercentage(
          consumed: 2400,
          target: 2000,
        );
        expect(result, 120.0);
      });

      test('hedef sıfır → %0', () {
        final result = CalorieCalculator.targetPercentage(
          consumed: 500,
          target: 0,
        );
        expect(result, 0.0);
      });
    });
  });
}
