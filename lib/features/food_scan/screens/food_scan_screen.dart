// =============================================================================
// lib/features/food_scan/screens/food_scan_screen.dart
// NutriSense — Besin Tarama Ana Ekranı (Sekmede Görünen)
//
// BottomNavigationBar'daki "Tara" sekmesinin içeriği.
// CameraScreen'e yönlendirme, son tarama sonuçları, hızlı erişim.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/tts_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/accessible_card.dart';
import '../../../shared/widgets/accessible_text.dart';
import '../models/camera_state.dart';
import 'camera_screen.dart';

/// Besin tarama ana ekranı — sekmede görünen sayfa
class FoodScanScreen extends ConsumerStatefulWidget {
  const FoodScanScreen({super.key});

  @override
  ConsumerState<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends ConsumerState<FoodScanScreen> {
  // Son tarama sonuçları (kamera ekranından dönüş)
  String? _lastFood;
  double? _lastCalories;
  double? _lastConfidence;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityUtils.announce(
        'Besin tarama ekranı. '
        'Kamerayı açmak için tara butonuna basın veya sesli komut verin.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Besin Tara'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Ana Tara Butonu (Büyük, erişilebilir) ──
            Semantics(
              label: 'Kamerayı aç ve besin taramaya başla. '
                  'Kamera açılacak ve yiyecek otomatik olarak tanınacak.',
              button: true,
              child: InkWell(
                onTap: _openCamera,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          size: 64,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Besini Tara',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kameraya tutun, otomatik tanınsın',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Son Tarama Sonucu ──
            if (_lastFood != null) ...[
              AccessibleText.headline(
                'Son Tarama',
                context: context,
                semanticLabel: 'Son tarama sonucu',
              ),
              const SizedBox(height: 12),
              AccessibleCard(
                semanticLabel: 'Son taranan besin: $_lastFood, '
                    '${_lastCalories?.toStringAsFixed(0)} kalori, '
                    'güven yüzde ${(_lastConfidence != null ? (_lastConfidence! * 100).toStringAsFixed(0) : '--')}',
                title: _lastFood!,
                subtitle:
                    'Güven: %${(_lastConfidence != null ? (_lastConfidence! * 100).toStringAsFixed(0) : '--')}',
                trailing: '${_lastCalories?.toStringAsFixed(0) ?? '--'} kcal',
                leading: const Icon(Icons.restaurant, size: 32),
                backgroundColor: AppTheme.successColor.withOpacity(0.1),
                onTap: () {
                  final tts = ref.read(ttsServiceProvider);
                  tts.speakFoodResult(
                    foodName: _lastFood!,
                    calories: _lastCalories ?? 0,
                    portionGrams: 100,
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // ── Hızlı Erişim Butonları ──
            AccessibleText.headline(
              'Hızlı Erişim',
              context: context,
              semanticLabel: 'Hızlı erişim bölümü',
            ),
            const SizedBox(height: 12),

            // Manuel besin girişi
            AccessibleButton(
              label: 'Manuel Besin Girişi',
              semanticLabel:
                  'Kamera kullanmadan besin adını söyleyerek veya yazarak kaydedin',
              icon: Icons.edit_note,
              type: AccessibleButtonType.outlined,
              onPressed: () {
                AccessibilityUtils.announce(
                  'Manuel besin girişi ekranı açılıyor.',
                );
              },
            ),
            const SizedBox(height: 12),

            // Sesli besin arama
            AccessibleButton(
              label: 'Sesli Besin Arama',
              semanticLabel: 'Besin adını söyleyerek kalori bilgisini öğrenin',
              icon: Icons.mic,
              type: AccessibleButtonType.outlined,
              onPressed: () {
                AccessibilityUtils.announce(
                  'Sesli arama başlatılıyor. Besin adını söyleyin.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Kamera ekranını açar ve sonucu bekler
  Future<void> _openCamera() async {
    await AccessibilityUtils.mediumHaptic();
    AccessibilityUtils.announce('Kamera açılıyor.');

    if (!mounted) return;

    // CameraScreen'e git, sonucu bekle
    final result = await Navigator.of(context).push<CameraState>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );

    // Sonuç dönerse güncelle
    if (result != null &&
        result.status == CameraStatus.saved &&
        result.recognizedFood != null) {
      setState(() {
        _lastFood = result.recognizedFood;
        _lastCalories = result.calories;
        _lastConfidence = result.confidence;
      });

      AccessibilityUtils.announce(
        'Tarama tamamlandı. ${result.recognizedFood} kaydedildi.',
      );
    }
  }
}
