import 'package:flutter/material.dart';

import '../../../shared/models/food_analysis_model.dart';

class AccessiblePortionSelector extends StatelessWidget {
  static const quickGrams = <double>[50, 100, 150, 200];

  final FoodAnalysisResult result;
  final bool enabled;
  final bool loading;
  final void Function(double value, String unit) onSelected;
  final VoidCallback onManual;
  final VoidCallback onVoice;

  const AccessiblePortionSelector({
    super.key,
    required this.result,
    required this.enabled,
    required this.loading,
    required this.onSelected,
    required this.onManual,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: result.portionIsEstimate
          ? 'Tahmini porsiyon ${result.portionGrams.toStringAsFixed(0)} gram. Değiştirebilirsiniz.'
          : 'Seçilen porsiyon ${result.portionGrams.toStringAsFixed(0)} gram.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            result.portionIsEstimate
                ? 'Tahmini ${result.portionGrams.toStringAsFixed(0)} g — değiştirmek ister misiniz?'
                : 'Seçilen porsiyon: ${result.portionGrams.toStringAsFixed(0)} g',
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final grams in quickGrams)
                ChoiceChip(
                  label: Text('${grams.toStringAsFixed(0)} g'),
                  selected: result.portionUnit == 'gram' &&
                      result.portionValue == grams &&
                      !result.portionIsEstimate,
                  onSelected: enabled && !loading
                      ? (_) => onSelected(grams, 'gram')
                      : null,
                ),
              for (final option in result.portionOptions)
                ActionChip(
                  label: Text('1 ${option.unit}'),
                  tooltip:
                      '1 ${option.unit}, yaklaşık ${option.gramsPerUnit.toStringAsFixed(0)} gram',
                  onPressed: enabled && !loading
                      ? () => onSelected(1, option.unit)
                      : null,
                ),
              ActionChip(
                avatar: const Icon(Icons.edit, size: 18),
                label: const Text('Başka'),
                onPressed: enabled && !loading ? onManual : null,
              ),
              ActionChip(
                avatar: const Icon(Icons.mic, size: 18),
                label: const Text('Sesle'),
                tooltip: 'Porsiyonu sesle söyle',
                onPressed: enabled && !loading ? onVoice : null,
              ),
              if (loading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
