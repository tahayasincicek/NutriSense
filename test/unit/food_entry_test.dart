import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/models/food_analysis_model.dart';

void main() {
  final fixture = <String, dynamic>{
    'id': '550e8400-e29b-41d4-a716-446655440000',
    'food_name': 'apple',
    'food_name_tr': 'Elma',
    'canonical_food_id': 'food.apple',
    'calories': 78.0,
    'calories_per_100g': 52.0,
    'portion_g': 150.0,
    'portion_value': 150.0,
    'portion_unit': 'gram',
    'portion_method': 'user_selected',
    'portion_is_estimate': false,
    'meal_type': 'atistirmalik',
    'confidence': 0.93,
    'recognition_source': 'google_vision',
    'nutrition_source': 'nutritionix',
    'nutrition_reliability': 'verified_provider',
    'is_corrected': true,
    'is_user_confirmed': true,
    'nutrients': {
      'protein': 0.4,
      'carbs': 20.7,
      'fat': 0.3,
      'fiber': 3.6,
    },
    'logged_at': '2026-07-17T10:30:00Z',
    'updated_at': '2026-07-17T10:31:00Z',
  };

  test('FoodLogEntry kanonik sözleşmeyi kayıpsız serileştirir', () {
    final entry = FoodLogEntry.fromJson(fixture);
    final restored = FoodLogEntry.fromJson(entry.toJson());

    expect(restored.id, entry.id);
    expect(restored.canonicalFoodId, 'food.apple');
    expect(restored.portionG, 150);
    expect(restored.recognitionSource, 'google_vision');
    expect(restored.isCorrected, isTrue);
    expect(restored.nutrients.carbs, 20.7);
  });

  test('tek semantik cümle porsiyon, makro, kaynak ve düzeltmeyi kapsar', () {
    final semantics = FoodLogEntry.fromJson(fixture).semanticLabel;

    expect(semantics, contains('Elma, 150 gram, 78 kalori'));
    expect(semantics, contains('20.7 gram karbonhidrat'));
    expect(semantics, contains('çevrim içi görüntü tanıma'));
    expect(semantics, contains('Düzeltilmiş'));
  });

  test('porsiyon etiketi kaynak birimini korur', () {
    final item = Map<String, dynamic>.from(fixture)
      ..['portion_value'] = 2
      ..['portion_unit'] = 'dilim';

    expect(FoodLogEntry.fromJson(item).portionLabel, '2 dilim');
  });
}
