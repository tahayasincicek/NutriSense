import 'package:flutter/material.dart';

import '../../../shared/models/food_analysis_model.dart';

class AccessiblePortionSelector extends StatelessWidget {
  static const quickGrams = <double>[50, 100, 150, 200];

  /// İçeceklerde hazır hacimler.
  ///
  /// "1 ml" düğmesi anlamsız olurdu; içecek bardak ve şişe ölçüsüyle
  /// tüketiliyor. 200 bir bardak, 250 bir kutu ayran, 330 bir kutu içecek,
  /// 500 küçük şişe.
  static const quickMillilitres = <double>[200, 250, 330, 500];

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

  bool get _hasVolume =>
      result.portionOptions.any((option) => option.unit == 'ml');

  /// Ekranda ve seslendirmede gösterilen porsiyon.
  ///
  /// Kullanıcı "250 ml" seçtiyse ona "258 gram" demek kafa karıştırır;
  /// seçtiği birimle geri okunur, gram karşılığı yalnız tahminlerde
  /// gösterilir.
  String get _portionLabel {
    final unit = result.portionUnit;
    if (unit == 'gram' || unit.isEmpty) {
      return '${result.portionGrams.toStringAsFixed(0)} g';
    }
    final value = result.portionValue;
    final written = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$written $unit';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: result.portionIsEstimate
          ? 'Tahmini porsiyon $_portionLabel. Değiştirebilirsiniz.'
          : 'Seçilen porsiyon $_portionLabel.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            result.portionIsEstimate
                ? 'Tahmini $_portionLabel — değiştirmek ister misiniz?'
                : 'Seçilen porsiyon: $_portionLabel',
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
              // Hacim birimi varsa gram yerine mililitre seçilebilir; su ya
              // da ayran içen kullanıcı artık gram tahmin etmek zorunda
              // değil. Litre tek başına çok büyük olduğu için düğme
              // verilmez, "Başka" ile yazılabilir.
              if (_hasVolume)
                for (final millilitres in quickMillilitres)
                  ChoiceChip(
                    label: Text('${millilitres.toStringAsFixed(0)} ml'),
                    selected: result.portionUnit == 'ml' &&
                        result.portionValue == millilitres,
                    onSelected: enabled && !loading
                        ? (_) => onSelected(millilitres, 'ml')
                        : null,
                  ),
              for (final option in result.portionOptions)
                if (option.unit != 'ml' && option.unit != 'litre')
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
