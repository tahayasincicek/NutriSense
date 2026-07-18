import '../../../shared/models/food_analysis_model.dart';

enum RecognitionBand { high, medium, low }

class RecognitionPolicy {
  final double highThreshold;
  final double lowThreshold;

  const RecognitionPolicy({
    this.highThreshold = 0.85,
    this.lowThreshold = 0.60,
  }) : assert(lowThreshold < highThreshold);

  RecognitionBand classify(FoodAnalysisResult result) {
    if (!result.canConfirm ||
        result.nutritionStatus == 'not_found' ||
        result.totalCalories <= 0 ||
        result.confidence < lowThreshold) {
      return RecognitionBand.low;
    }
    if (result.confidence >= highThreshold) return RecognitionBand.high;
    return RecognitionBand.medium;
  }

  List<FoodCandidate> candidates(FoodAnalysisResult result) =>
      result.candidates.take(3).toList(growable: false);
}
