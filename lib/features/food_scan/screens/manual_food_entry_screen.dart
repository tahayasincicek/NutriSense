// =============================================================================
// lib/features/food_scan/screens/manual_food_entry_screen.dart
// NutriSense — Manuel / Sesli Besin Girişi Ekranı
//
// Kamera kullanmadan besin adını yazarak veya söyleyerek kalori bilgisi alma.
// STT ile sesli besin arama → Backend'e text gönderme → Nutritionix lookup.
// Porsiyon seçimi + kaydetme.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/models/food_analysis_model.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/stt_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/accessible_card.dart';
import '../../history/state/history_controller.dart';

class ManualFoodEntryScreen extends ConsumerStatefulWidget {
  const ManualFoodEntryScreen({super.key});

  @override
  ConsumerState<ManualFoodEntryScreen> createState() =>
      _ManualFoodEntryScreenState();
}

class _ManualFoodEntryScreenState extends ConsumerState<ManualFoodEntryScreen> {
  static const _uuid = Uuid();
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  late final AccessibilityService _accessibility;
  late final SttService _stt;

  bool _isSearching = false;
  bool _isListening = false;
  bool _isSaving = false;
  List<FoodSearchResult>? _results;
  FoodSearchResult? _selectedResult;
  double _portionGrams = 100;
  String _portionUnit = 'gram';
  String? _error;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _stt = ref.read(sttServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibility.speak(
        'Manuel besin girişi ekranı. '
        'Besin adını yazabilir ya da söyleyebilirsiniz.',
        priority: TtsPriority.high,
      );
    });
  }

  /// Sesli besin arama başlat
  Future<void> _startVoiceSearch() async {
    if (!_stt.isAvailable) {
      await _stt.initialize();
    }

    setState(() {
      _isListening = true;
      _error = null;
    });

    _accessibility.speak(
      'Dinliyorum. Besin adını söyleyin.',
      priority: TtsPriority.high,
    );

    await _stt.startListening(
      onResult: (result) {
        if (result.isFinal && result.text.isNotEmpty) {
          setState(() {
            _searchController.text = result.text;
            _isListening = false;
          });
          _searchFood(result.text);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        _accessibility.speak(
          'Ses tanıma hatası. Lütfen tekrar deneyin.',
          priority: TtsPriority.high,
        );
      },
    );
  }

  /// Besin arama
  Future<void> _searchFood(String query) async {
    if (query.trim().isEmpty) {
      _accessibility.speak(
        'Lütfen bir besin adı girin.',
        priority: TtsPriority.normal,
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
      _results = null;
      _selectedResult = null;
    });

    _accessibility.speak(
      '$query aranıyor...',
      priority: TtsPriority.normal,
    );

    final api = ref.read(apiServiceProvider);
    final result = await api.searchFoodByName(query: query.trim());

    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      final analysis = result.data!;
      final searchResult = FoodSearchResult(
        foodName: analysis.foodNameTr,
        displayName: analysis.foodNameTr,
        caloriesPer100g: analysis.caloriesPer100g,
        portionOptions: analysis.portionOptions,
      );

      setState(() {
        _isSearching = false;
        _results = [searchResult];
      });

      final firstResult = searchResult;
      _accessibility.speak(
        '1 sonuç bulundu. '
        'İlk sonuç: ${firstResult.displayName}, '
        '100 gramda ${firstResult.caloriesPer100g.toStringAsFixed(0)} kalori.',
        priority: TtsPriority.high,
      );
    } else {
      setState(() {
        _isSearching = false;
        _error = result.errorMessage ?? 'Besin bulunamadı.';
      });

      _accessibility.speak(
        '$query için sonuç bulunamadı. Lütfen farklı bir isim deneyin.',
        priority: TtsPriority.high,
      );
    }
  }

  /// Besin seçimi
  void _selectResult(FoodSearchResult result) {
    setState(() {
      _selectedResult = result;
      _portionUnit = 'gram';
      _portionGrams = result.defaultPortionGrams;
    });

    _accessibility.speak(
      '${result.displayName} seçildi. '
      'Porsiyon: $_portionLabel, '
      '${_calculateCalories().toStringAsFixed(0)} kalori. '
      'Porsiyonu değiştirebilir ya da kaydet diyerek kaydedebilirsiniz.',
      priority: TtsPriority.high,
    );
  }

  /// Seçili besinin kabul ettiği birimler; gram her zaman ilk sırada.
  List<String> get _availableUnits => [
        'gram',
        for (final option in _selectedResult?.portionOptions ?? const [])
          if (option.unit != 'litre') option.unit,
      ];

  /// Seçili birimin bir biriminin kaç gram geldiği.
  double get _gramsPerUnit {
    if (_portionUnit == 'gram') return 1;
    for (final option in _selectedResult?.portionOptions ?? const []) {
      if (option.unit == _portionUnit) return option.gramsPerUnit;
    }
    return 1;
  }

  /// Kaydırıcının o birimdeki aralığı ve adımı.
  ///
  /// Gram için 10-1000 uygun; mililitrede 10 ml anlamsız küçük, adette ise
  /// 1000 saçma. Aralık birime göre değişmezse kaydırıcı kullanılamaz hâle
  /// geliyordu.
  ({double min, double max, int divisions}) get _sliderRange =>
      switch (_portionUnit) {
        'gram' => (min: 10, max: 1000, divisions: 99),
        'ml' => (min: 50, max: 1000, divisions: 38),
        // adet, dilim, kase
        _ => (min: 1, max: 10, divisions: 18),
      };

  /// Kullanıcının seçtiği porsiyonun kendi birimindeki yazımı.
  String get _portionLabel {
    if (_portionUnit == 'gram') return '${_portionGrams.toStringAsFixed(0)} g';
    final value = _portionValue;
    final written = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$written $_portionUnit';
  }

  /// Kaydırıcıda duran değer, seçili birim cinsinden.
  double get _portionValue =>
      _portionUnit == 'gram' ? _portionGrams : _portionGrams / _gramsPerUnit;

  double _calculateCalories() {
    if (_selectedResult == null) return 0;
    return (_selectedResult!.caloriesPer100g / 100) * _portionGrams;
  }

  /// Birim değişince gram karşılığı korunur, yalnız ölçek değişir.
  void _changeUnit(String unit) {
    if (unit == _portionUnit) return;
    setState(() {
      _portionUnit = unit;
      final range = _sliderRange;
      final converted = unit == 'gram' ? _portionGrams : _portionValue;
      _portionGrams = converted.clamp(range.min, range.max) * _gramsPerUnit;
    });
    _accessibility.speak(
      'Birim $unit. Porsiyon $_portionLabel, '
      '${_calculateCalories().toStringAsFixed(0)} kalori.',
      priority: TtsPriority.normal,
    );
  }

  /// Besini kaydet
  Future<void> _saveEntry() async {
    if (_selectedResult == null) return;

    setState(() => _isSaving = true);

    final api = ref.read(apiServiceProvider);
    final result = await api.createManualFoodLog(
      captureId: _uuid.v4(),
      foodName: _selectedResult!.foodName,
      foodNameTr: _selectedResult!.displayName,
      // Kullanıcının seçtiği birim aynen gönderilir; grama çevirmeyi sunucu
      // doğrulanmış dönüşümle yapar, istemci tahmin yürütmez.
      portionValue: _portionUnit == 'gram' ? _portionGrams : _portionValue,
      portionUnit: _portionUnit,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.isSuccess) {
      _accessibility.speak(
        '${_selectedResult!.displayName} kaydedildi. '
        '$_portionLabel, '
        '${_calculateCalories().toStringAsFixed(0)} kalori.',
        priority: TtsPriority.high,
      );
      await AccessibilityUtils.successHaptic();
      // Geçmişi yenile
      ref.read(historyControllerProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _accessibility.speak(
        'Kayıt başarısız. ${result.errorMessage ?? "Lütfen tekrar deneyin."}',
        priority: TtsPriority.high,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manuel Besin Girişi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Arama alanı
            Semantics(
              label: 'Besin adı arama alanı',
              textField: true,
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: 'Besin adı',
                  hintText: 'Örn: elma, pilav, köfte...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mikrofon butonu
                      // tooltip düğmenin kendi adıdır; ad yalnız dıştaki
                      // Semantics'te kalırsa ekran okuyucu düğmeye
                      // odaklandığında yalnız "düğme" der.
                      Semantics(
                        label: _isListening
                            ? 'Dinleniyor... Durdurmak için basın'
                            : 'Sesli arama. Besin adını söyleyin',
                        button: true,
                        excludeSemantics: true,
                        child: IconButton(
                          tooltip: _isListening
                              ? 'Dinleniyor. Durdurmak için basın'
                              : 'Sesli arama. Besin adını söyleyin',
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none_rounded,
                            color: _isListening
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                          onPressed: _isListening
                              ? () {
                                  _stt.cancelListening();
                                  setState(() => _isListening = false);
                                }
                              : _startVoiceSearch,
                        ),
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _searchFood,
              ),
            ),
            const SizedBox(height: 12),

            // Ara butonu
            AccessibleButton(
              label: 'Ara',
              semanticLabel: 'Girilen besin adını ara',
              icon: Icons.search_rounded,
              onPressed: _isSearching
                  ? null
                  : () => _searchFood(_searchController.text),
            ),

            // Dinleme göstergesi
            if (_isListening) ...[
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                label: 'Dinleniyor... Besin adını söyleyin',
                child: Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.hearing,
                            color: theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Dinleniyor... Besin adını söyleyin',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Yükleniyor göstergesi
            if (_isSearching) ...[
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                label: 'Besin aranıyor',
                child: const Center(child: CircularProgressIndicator()),
              ),
            ],

            // Hata mesajı
            if (_error != null) ...[
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style:
                          TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ),
              ),
            ],

            // Sonuçlar
            if (_results != null && _selectedResult == null) ...[
              const SizedBox(height: 20),
              Text('Sonuçlar', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...List.generate(_results!.length, (index) {
                final item = _results![index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AccessibleCard(
                    semanticLabel:
                        '${item.displayName}, 100 gramda ${item.caloriesPer100g.toStringAsFixed(0)} kalori. Seçmek için dokunun.',
                    title: item.displayName,
                    subtitle:
                        '100g: ${item.caloriesPer100g.toStringAsFixed(0)} kcal',
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8EFEA),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.restaurant_rounded,
                            size: 22, color: AppTheme.primaryColor),
                      ),
                    ),
                    onTap: () => _selectResult(item),
                  ),
                );
              }),
            ],

            // Seçilen besin detayları + porsiyon
            if (_selectedResult != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_selectedResult!.displayName,
                          style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 16),
                      Semantics(
                        label:
                            '${_calculateCalories().toStringAsFixed(0)} kalori',
                        child: Text(
                          '${_calculateCalories().toStringAsFixed(0)} kcal',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Besin birden çok birim kabul ediyorsa seçim sunulur;
                      // yalnız gram varsa satır hiç çizilmez.
                      if (_availableUnits.length > 1) ...[
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final unit in _availableUnits)
                              ChoiceChip(
                                label: Text(unit == 'gram' ? 'gram' : unit),
                                selected: _portionUnit == unit,
                                onSelected: (_) => _changeUnit(unit),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'Porsiyon: $_portionLabel',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Semantics(
                        label: 'Porsiyon kaydırıcısı. '
                            'Şu anki değer: $_portionLabel.',
                        slider: true,
                        child: Slider(
                          value: _portionValue.clamp(
                              _sliderRange.min, _sliderRange.max),
                          min: _sliderRange.min,
                          max: _sliderRange.max,
                          divisions: _sliderRange.divisions,
                          label: _portionLabel,
                          onChanged: (v) => setState(
                            () => _portionGrams = v * _gramsPerUnit,
                          ),
                          onChangeEnd: (v) {
                            _accessibility.speak(
                              '$_portionLabel. '
                              '${_calculateCalories().toStringAsFixed(0)} kalori.',
                              priority: TtsPriority.normal,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: AccessibleButton(
                              label: 'Değiştir',
                              semanticLabel: 'Farklı besin seç',
                              icon: Icons.swap_horiz_rounded,
                              type: AccessibleButtonType.outlined,
                              onPressed: () {
                                setState(() => _selectedResult = null);
                                _accessibility.speak(
                                  'Besin seçimi iptal edildi. Başka bir besin seçin.',
                                  priority: TtsPriority.normal,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AccessibleButton(
                              label: _isSaving ? 'Kaydediliyor...' : 'Kaydet',
                              semanticLabel:
                                  '${_selectedResult!.displayName}, $_portionLabel, ${_calculateCalories().toStringAsFixed(0)} kalori olarak kaydet',
                              icon: Icons.save_rounded,
                              onPressed: _isSaving ? null : _saveEntry,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    if (_isListening) _stt.cancelListening();
    super.dispose();
  }
}

/// Backend'den dönen besin arama sonucu
class FoodSearchResult {
  final String foodName;
  final String displayName;
  final double caloriesPer100g;
  final double defaultPortionGrams;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const FoodSearchResult({
    required this.foodName,
    required this.displayName,
    required this.caloriesPer100g,
    this.defaultPortionGrams = 100,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.portionOptions = const [],
  });

  /// Besinin gram dışında kabul ettiği birimler.
  ///
  /// Arama zaten bu bilgiyi döndürüyordu ama ekran yalnız kaloriyi alıp
  /// gerisini atıyordu; bu yüzden bir bardak ayran gram cinsinden tahmin
  /// edilmek zorundaydı.
  final List<PortionOption> portionOptions;

  factory FoodSearchResult.fromJson(Map<String, dynamic> json) {
    return FoodSearchResult(
      foodName: json['food_name'] as String? ?? '',
      displayName:
          json['display_name'] as String? ?? json['food_name'] as String? ?? '',
      caloriesPer100g: (json['calories_per_100g'] as num?)?.toDouble() ?? 0,
      defaultPortionGrams:
          (json['default_portion_grams'] as num?)?.toDouble() ?? 100,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
    );
  }
}
