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
        leading: const Padding(
          padding: EdgeInsets.only(left: 18, top: 10, bottom: 10),
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE9DCC9), Color(0xFF9EB7A7)],
                ),
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                size: 22,
                color: AppTheme.primaryDark,
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
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF315B49), AppTheme.primaryDark],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: Stack(
                children: [
                  const Positioned(
                    right: -35,
                    top: -40,
                    child: _DecorativePlate(size: 170),
                  ),
                  const Positioned(
                    right: 52,
                    bottom: -44,
                    child: _DecorativePlate(size: 126, opacity: 0.08),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: ExcludeSemantics(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 210),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: AppTheme.primaryDark,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(height: 42),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                              child: const Text(
                                'KAMERA İLE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
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

class _DecorativePlate extends StatelessWidget {
  const _DecorativePlate({required this.size, this.opacity = 0.12});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: opacity),
          shape: BoxShape.circle,
          border: Border.all(
            width: 18,
            color: Colors.white.withValues(alpha: opacity * 0.7),
          ),
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
