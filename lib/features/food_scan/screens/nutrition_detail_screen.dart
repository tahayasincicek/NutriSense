// =============================================================================
// lib/features/food_scan/screens/nutrition_detail_screen.dart
// NutriSense — Besin Değerleri Detay Ekranı
//
// Tanınan besinin tam besin değerleri:
//   - Kalori, Protein, Karbonhidrat, Yağ, Lif
//   - Renkli progress bar'lar
//   - TTS ile sesli okuma
//   - Kaydet / Tekrar tara butonları
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/food_analysis_model.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/contextual_voice_command.dart';
import '../../../shared/services/voice_command_service.dart';
import '../../../shared/widgets/accessible_button.dart';

class NutritionDetailScreen extends ConsumerStatefulWidget {
  const NutritionDetailScreen({
    super.key,
    required this.foodName,
    required this.foodNameTr,
    required this.calories,
    required this.portionGrams,
    required this.confidence,
    this.nutrients,
  });

  final String foodName;
  final String foodNameTr;
  final double calories;
  final double portionGrams;
  final double confidence;
  final NutrientData? nutrients;

  @override
  ConsumerState<NutritionDetailScreen> createState() =>
      _NutritionDetailScreenState();
}

class _NutritionDetailScreenState extends ConsumerState<NutritionDetailScreen> {
  late final AccessibilityService _accessibility;
  late final VoiceCommandService _voice;
  OnCommandRecognized? _previousCommandHandler;
  late final OnCommandRecognized _detailCommandHandler;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _voice = ref.read(voiceCommandServiceProvider);
    _previousCommandHandler = _voice.onCommandRecognized;
    _detailCommandHandler = _handleVoiceCommand;
    _voice.onCommandRecognized = _detailCommandHandler;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _announceDetails();
    });
  }

  void _handleVoiceCommand(CommandResult result) {
    if (!mounted || _completed || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    // Re-parse the actual words in this confirmation context: a fuzzy global
    // match must never authorize saving a food record.
    final intent = const ContextualVoiceCommandParser().parse(
      result.rawText,
      context: VoiceInteractionContext.scanConfirmation,
    );
    if (intent.accepted && intent.isExact) {
      switch (intent.action) {
        case ContextualVoiceAction.listenEntry:
          _announceDetails();
          return;
        case ContextualVoiceAction.save:
        case ContextualVoiceAction.yes:
          _finish('saved');
          return;
        case ContextualVoiceAction.retake:
        case ContextualVoiceAction.no:
        case ContextualVoiceAction.cancel:
        case ContextualVoiceAction.back:
          _finish('rescan');
          return;
        default:
          break;
      }
    }
    _accessibility.speak(
      'Bilgileri dinlemek için besin bilgilerini oku, '
      'kaydetmek için kaydet, yeniden taramak için tekrar çek deyin.',
      priority: TtsPriority.high,
    );
  }

  void _finish(String action) {
    if (_completed || ModalRoute.of(context)?.isCurrent != true) return;
    _completed = true;
    // The camera screen performs the server confirmation and announces its
    // outcome. Do not announce success before that request has completed.
    Navigator.of(context).pop(action);
  }

  @override
  void dispose() {
    if (identical(_voice.onCommandRecognized, _detailCommandHandler)) {
      _voice.onCommandRecognized = _previousCommandHandler;
    }
    super.dispose();
  }

  void _announceDetails() {
    final buffer = StringBuffer();
    buffer.write('${widget.foodNameTr} tanındı. ');
    buffer.write('${widget.portionGrams.toStringAsFixed(0)} gram, ');
    buffer.write('${widget.calories.toStringAsFixed(0)} kalori. ');

    if (widget.nutrients != null) {
      final n = widget.nutrients!;
      buffer.write('Besin değerleri: ');
      buffer.write('${n.protein.toStringAsFixed(1)} gram protein, ');
      buffer.write('${n.carbs.toStringAsFixed(1)} gram karbonhidrat, ');
      buffer.write('${n.fat.toStringAsFixed(1)} gram yağ, ');
      buffer.write('${n.fiber.toStringAsFixed(1)} gram lif. ');
    }

    buffer.write(
        'Güven yüzdesi: ${(widget.confidence * 100).toStringAsFixed(0)}. ');
    buffer.write('Kaydetmek için kaydet, bilgileri yeniden dinlemek için '
        'besin bilgilerini oku deyin.');

    _accessibility.speak(buffer.toString(), priority: TtsPriority.high);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nutrients = widget.nutrients;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Besin Detayları'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Semantics(
            label: 'Besin bilgilerini sesli oku',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.volume_up_rounded),
              tooltip: 'Sesli Oku',
              onPressed: _announceDetails,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Besin başlık kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant_rounded,
                          size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        widget.foodNameTr,
                        style: theme.textTheme.headlineLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.portionGrams.toStringAsFixed(0)}g porsiyon',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Güven skoru
                    Semantics(
                      label:
                          'Tanıma güveni: yüzde ${(widget.confidence * 100).toStringAsFixed(0)}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _confidenceColor(widget.confidence)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Güven: %${(widget.confidence * 100).toStringAsFixed(0)}',
                          style: TextStyle(
                            color: _confidenceColor(widget.confidence),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Kalori kartı
            Semantics(
              label: '${widget.calories.toStringAsFixed(0)} kalori',
              child: Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Kalori',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.calories.toStringAsFixed(0),
                        style: theme.textTheme.displayLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'kcal',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Makro besin değerleri
            if (nutrients != null) ...[
              Text('Besin Değerleri', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _NutrientBar(
                label: 'Protein',
                value: nutrients.protein,
                unit: 'g',
                color: const Color(0xFF4CAF50),
                maxValue: 50,
                ttsLabel:
                    '${nutrients.protein.toStringAsFixed(1)} gram protein',
              ),
              const SizedBox(height: 10),
              _NutrientBar(
                label: 'Karbonhidrat',
                value: nutrients.carbs,
                unit: 'g',
                color: const Color(0xFFFF9800),
                maxValue: 100,
                ttsLabel:
                    '${nutrients.carbs.toStringAsFixed(1)} gram karbonhidrat',
              ),
              const SizedBox(height: 10),
              _NutrientBar(
                label: 'Yağ',
                value: nutrients.fat,
                unit: 'g',
                color: const Color(0xFFF44336),
                maxValue: 50,
                ttsLabel: '${nutrients.fat.toStringAsFixed(1)} gram yağ',
              ),
              const SizedBox(height: 10),
              _NutrientBar(
                label: 'Lif',
                value: nutrients.fiber,
                unit: 'g',
                color: const Color(0xFF795548),
                maxValue: 30,
                ttsLabel: '${nutrients.fiber.toStringAsFixed(1)} gram lif',
              ),
            ],

            const SizedBox(height: 32),

            // Aksiyon butonları
            AccessibleButton(
              label: 'Kaydet',
              semanticLabel:
                  '${widget.foodNameTr} besinini ${widget.calories.toStringAsFixed(0)} kalori olarak kaydet',
              icon: Icons.save_rounded,
              onPressed: () => _finish('saved'),
            ),
            const SizedBox(height: 12),
            AccessibleButton(
              label: 'Tekrar Tara',
              semanticLabel: 'Farklı bir besin taramak için kameraya dön',
              icon: Icons.camera_alt_rounded,
              type: AccessibleButtonType.outlined,
              onPressed: () => _finish('rescan'),
            ),
          ],
        ),
      ),
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.8) return AppTheme.successColor;
    if (confidence >= 0.5) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}

class _NutrientBar extends StatelessWidget {
  const _NutrientBar({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.maxValue,
    required this.ttsLabel,
  });

  final String label;
  final double value;
  final String unit;
  final Color color;
  final double maxValue;
  final String ttsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (value / maxValue).clamp(0.0, 1.0);

    return Semantics(
      label: ttsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
