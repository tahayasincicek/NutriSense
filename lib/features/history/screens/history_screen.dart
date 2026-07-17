// =============================================================================
// lib/features/history/screens/history_screen.dart
// NutriSense — Yemek Geçmişi Ekranı
//
// Günlük yemek kayıtlarını listeler, toplam kaloriyi gösterir.
// Erişilebilir kart yapısı ve sesli özet desteği.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/widgets/accessible_card.dart';

/// Yemek geçmişi ekranı
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  // Örnek veriler — gerçek uygulamada API'den gelecek
  final List<_MockFoodLog> _logs = [
    _MockFoodLog('Kahvaltı', 'Yumurta', 155, '2 adet', Icons.egg_alt),
    _MockFoodLog(
        'Kahvaltı', 'Tam Buğday Ekmek', 80, '1 dilim', Icons.bakery_dining),
    _MockFoodLog('Öğle', 'Tavuk Göğsü', 231, '150g', Icons.restaurant),
    _MockFoodLog('Öğle', 'Pilav', 206, '1 porsiyon', Icons.rice_bowl),
    _MockFoodLog('Atıştırmalık', 'Elma', 78, '1 adet', Icons.apple),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final total = _logs.fold<double>(0, (sum, log) => sum + log.calories);
      AccessibilityUtils.announce(
        'Yemek geçmişi ekranı. '
        'Bugün ${_logs.length} öğün, toplam ${total.toStringAsFixed(0)} kalori.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCalories =
        _logs.fold<double>(0, (sum, log) => sum + log.calories);
    final target = AppConstants.defaultDailyCalorieTarget;
    final remaining = target - totalCalories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yemek Geçmişi'),
      ),
      body: Column(
        children: [
          // ── Günlük Özet Kartı ──
          Semantics(
            label: 'Günlük kalori özeti. '
                'Toplam ${totalCalories.toStringAsFixed(0)} kalori tüketildi. '
                'Hedefe ${remaining.toStringAsFixed(0)} kalori kaldı.',
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    Text(
                      'Bugünkü Toplam',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${totalCalories.toStringAsFixed(0)} kcal',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // İlerleme çubuğu
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (totalCalories / target).clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      remaining > 0
                          ? 'Hedefe ${remaining.toStringAsFixed(0)} kcal kaldı'
                          : 'Hedef aşıldı!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Yemek Listesi ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return AccessibleCard(
                  semanticLabel: '${log.mealType}: ${log.name}, '
                      '${log.calories.toStringAsFixed(0)} kalori, '
                      '${log.portion}',
                  semanticHint: 'Detayları görmek için çift dokunun',
                  title: log.name,
                  subtitle: '${log.mealType} • ${log.portion}',
                  trailing: '${log.calories.toStringAsFixed(0)} kcal',
                  leading: Icon(log.icon, size: 32),
                  onTap: () {
                    AccessibilityUtils.announce(
                      '${log.name}, ${log.portion}, '
                      '${log.calories.toStringAsFixed(0)} kalori',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Mock veri sınıfı — geliştirme aşamasında kullanılır
class _MockFoodLog {
  final String mealType;
  final String name;
  final double calories;
  final String portion;
  final IconData icon;

  const _MockFoodLog(
      this.mealType, this.name, this.calories, this.portion, this.icon);
}
