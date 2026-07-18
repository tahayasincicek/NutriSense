import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/accessible_card.dart';
import '../../../shared/widgets/accessible_text.dart';
import '../models/camera_state.dart';
import 'camera_screen.dart';

/// Ana tarama ekranı. Yalnız sunum katmanını yönetir; kamera ve sonuç akışı
/// [CameraScreen] tarafından sağlanmaya devam eder.
class FoodScanScreen extends ConsumerStatefulWidget {
  const FoodScanScreen({super.key});

  @override
  ConsumerState<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends ConsumerState<FoodScanScreen> {
  String? _lastFood;
  double? _lastCalories;
  double? _lastConfidence;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityUtils.announce(
        'Besin tarama ekranı. Kamerayı açmak için tara butonuna basın veya sesli komut verin.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 18, top: 10, bottom: 10),
          child: ExcludeSemantics(
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFD8D8D8), width: 0.8),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/nutrition_scan_cover.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0.25, -0.35),
              ),
            ),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NutriSense', style: theme.textTheme.titleMedium),
            Text(
              'Gör, dinle, kaydet',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bugün', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              'Besinini kolayca tanı',
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: 18),
            _ScanHero(onTap: _openCamera),
            if (_lastFood != null) ...[
              const SizedBox(height: 28),
              const _SectionTitle(
                title: 'Son tarama',
                subtitle: 'En son onayladığınız besin',
              ),
              const SizedBox(height: 8),
              AccessibleCard(
                semanticLabel: 'Son taranan besin: $_lastFood, '
                    '${_lastCalories?.toStringAsFixed(0)} kalori, '
                    'güven yüzde ${(_lastConfidence != null ? (_lastConfidence! * 100).toStringAsFixed(0) : '--')}',
                title: _lastFood!,
                subtitle:
                    'Güven %${(_lastConfidence != null ? (_lastConfidence! * 100).toStringAsFixed(0) : '--')}',
                trailing: '${_lastCalories?.toStringAsFixed(0) ?? '--'} kcal',
                leading: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFE8EFEA),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.restaurant_rounded,
                      size: 26,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                onTap: () {
                  ref.read(accessibilityServiceProvider).speak(
                        '$_lastFood. Yaklaşık ${(_lastCalories ?? 0).toStringAsFixed(0)} kalori.',
                        priority: TtsPriority.high,
                        allowWhileScreenReaderActive: true,
                      );
                },
              ),
            ],
            const SizedBox(height: 28),
            const _SectionTitle(
              title: 'Hızlı erişim',
              subtitle: 'Kameraya alternatif giriş yöntemleri',
            ),
            const SizedBox(height: 10),
            AccessibleButton(
              label: 'Manuel Besin Girişi',
              semanticLabel:
                  'Kamera kullanmadan besin adını söyleyerek veya yazarak kaydedin',
              icon: Icons.edit_note_rounded,
              type: AccessibleButtonType.outlined,
              onPressed: () {
                AccessibilityUtils.announce(
                  'Manuel besin girişi ekranı açılıyor.',
                );
              },
            ),
            const SizedBox(height: 10),
            AccessibleButton(
              label: 'Sesli Besin Arama',
              semanticLabel: 'Besin adını söyleyerek kalori bilgisini öğrenin',
              icon: Icons.mic_none_rounded,
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

  Future<void> _openCamera() async {
    await AccessibilityUtils.mediumHaptic();
    AccessibilityUtils.announce('Kamera açılıyor.');

    if (!mounted) return;
    final result = await Navigator.of(context).push<CameraState>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/camera'),
        builder: (_) => const CameraScreen(),
      ),
    );

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

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Kamerayı aç ve besin taramaya başla. '
          'Kamera açılacak ve yiyecek otomatik olarak tanınacak.',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFFE7E7E5),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: Border.all(color: const Color(0xFFD8D8D8), width: 0.8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: Stack(
                children: [
                  const Positioned.fill(child: _CameraBackdrop()),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.38, 1],
                          colors: [Colors.transparent, Color(0xCC000000)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: ExcludeSemantics(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 238),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFD8D8D8),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: AppTheme.primaryDark,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(height: 82),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'KAMERA İLE',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Besini tara',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kameraya tutun, sonucunu dinleyin',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraBackdrop extends StatelessWidget {
  const _CameraBackdrop();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Image.asset(
          'assets/images/nutrition_scan_cover.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AccessibleText.headline(title, context: context),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
