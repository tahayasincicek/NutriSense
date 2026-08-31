import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/accessibility_service.dart';
import '../state/water_provider.dart';

class WaterTrackerScreen extends ConsumerWidget {
  const WaterTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterState = ref.watch(waterProvider);
    final theme = Theme.of(context);
    final accessibility = ref.read(accessibilityServiceProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Su Takibi'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Water Bubble / Progress Indicator
            Center(
              child: Semantics(
                label: 'Su tüketim ilerlemesi. Hedef ${waterState.goalAmount} mililitre. İçilen ${waterState.consumedAmount} mililitre.',
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 2),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Liquid effect (simple circle for now)
                      AnimatedContainer(
                        duration: const Duration(seconds: 1),
                        width: 180 * waterState.progress.clamp(0.0, 1.0),
                        height: 180 * waterState.progress.clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withOpacity(0.4),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.water_drop_rounded, size: 40, color: theme.colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(
                            '${waterState.consumedAmount}',
                            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                          ),
                          Text('ml', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              waterState.remaining > 0 
                ? 'Hedefine ulaşmak için ${waterState.remaining} ml kaldı' 
                : 'Harika! Bugünlük su hedefine ulaştın.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 40),
            
            // Fast Add Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _WaterAddButton(
                  amount: 200,
                  label: 'Bardak',
                  icon: Icons.local_drink_rounded,
                  onTap: () => _addWater(ref, 200, accessibility),
                ),
                _WaterAddButton(
                  amount: 500,
                  label: 'Şişe',
                  icon: Icons.bottle_rounded,
                  onTap: () => _addWater(ref, 500, accessibility),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Reset Button
            TextButton.icon(
              onPressed: () {
                ref.read(waterProvider.notifier).reset();
                accessibility.speak('Su tüketimi sıfırlandı.');
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Sıfırla'),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _addWater(WidgetRef ref, int ml, AccessibilityService acc) {
    ref.read(waterProvider.notifier).addWater(ml);
    AccessibilityUtils.lightHaptic();
    acc.speak('$ml mililitre su eklendi.');
  }
}

class _WaterAddButton extends StatelessWidget {
  final int amount;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _WaterAddButton({required this.amount, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '$amount mililitre $label ekle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 100,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 30),
              const SizedBox(height: 8),
              Text('$amount ml', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
