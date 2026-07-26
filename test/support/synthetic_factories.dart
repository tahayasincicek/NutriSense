import 'package:nutrisense/shared/models/auth_model.dart';
import 'package:nutrisense/shared/models/food_analysis_model.dart';

/// Yalnız testlerde kullanılan, gerçek kişi/sağlık verisi içermeyen fabrikalar.
abstract final class SyntheticFactories {
  static const userId = '9e4e5356-b491-4575-a9dd-c5abbc777fe9';
  static const logId = '550e8400-e29b-41d4-a716-446655440000';

  static const user = UserProfile(
    id: userId,
    email: 'fixture.user@nutrisense.invalid',
    fullName: 'Sentetik Kullanıcı',
    isActive: true,
  );

  static const approvedDietitian = DietitianAssignmentInfo(
    assignmentId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    status: 'approved',
    dietitianId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    dietitianName: 'Sandbox Diyetisyen',
    emailVerified: true,
    phoneVerified: true,
    emailMasked: 's****************@nutrisense.invalid',
    phoneMasked: '+*******0006',
  );

  static FoodAnalysisResult foodAnalysis() => FoodAnalysisResult.fromJson({
        'analysis_id': logId,
        'log_id': null,
        'food_name': 'elma',
        'food_name_tr': 'Elma',
        'canonical_food_id': 'food.apple',
        'normalization_version': 'fixture-v1',
        'confidence': 0.93,
        'portion_grams': 150.0,
        'portion_value': 150.0,
        'portion_unit': 'gram',
        'portion_method': 'source_default',
        'portion_is_estimate': true,
        'calories_per_100g': 52.0,
        'total_calories': 78.0,
        'nutrients': const {
          'protein': 0.4,
          'carbs': 20.7,
          'fat': 0.3,
          'fiber': 3.6,
        },
        'needs_confirmation': true,
        'can_confirm': true,
        'recognition_source': 'fixture_server',
        'nutrition_source': 'fixture_nutrition',
        'nutrition_status': 'available',
        'nutrition_reliability': 'verified_provider',
        'tts_text': 'Sentetik elma sonucu. Kaydetmeden önce onaylayın.',
        'candidates': const [
          {
            'food_name': 'elma',
            'food_name_tr': 'Elma',
            'confidence': 0.93,
          },
        ],
      });

  static FoodHistoryResult foodHistory() => FoodHistoryResult.fromJson({
        'user_id': userId,
        'from_date': '2026-07-26',
        'to_date': '2026-07-26',
        'total_days': 1,
        'average_daily_calories': 78.0,
        'total_calories': 78.0,
        'total_log_count': 1,
        'total_date_count': 1,
        'page': 1,
        'page_size': 7,
        'has_more': false,
        'daily_logs': [
          {
            'date': '2026-07-26',
            'total_calories': 78.0,
            'calorie_target': 2000.0,
            'remaining_calories': 1922.0,
            'total_protein': 0.4,
            'total_carbs': 20.7,
            'total_fat': 0.3,
            'meal_count': 1,
            'meals': const [
              {
                'meal_type': 'atistirmalik',
                'meal_type_tr': 'Atıştırmalık',
                'total_calories': 78.0,
                'food_count': 1,
              }
            ],
            'foods': const [
              {
                'id': logId,
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
                'recognition_source': 'fixture_server',
                'nutrition_source': 'fixture_nutrition',
                'nutrition_reliability': 'verified_provider',
                'is_corrected': false,
                'is_user_confirmed': true,
                'nutrients': {
                  'protein': 0.4,
                  'carbs': 20.7,
                  'fat': 0.3,
                  'fiber': 3.6,
                },
                'logged_at': '2026-07-26T09:30:00Z',
                'updated_at': '2026-07-26T09:30:00Z',
              }
            ],
          }
        ],
      });
}
