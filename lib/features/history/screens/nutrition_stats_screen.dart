import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/food_analysis_model.dart';
import '../state/history_controller.dart';

class NutritionStatsScreen extends ConsumerStatefulWidget {
  const NutritionStatsScreen({super.key});

  @override
  ConsumerState<NutritionStatsScreen> createState() =>
      _NutritionStatsScreenState();
}

class _NutritionStatsScreenState extends ConsumerState<NutritionStatsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(historyControllerProvider);

    return Scaffold(
      // Bu ekran Navigator.push ile açılır; arkasında AppShell
      // boyaması yoktur, arka planı temadan almalıdır.
      appBar: AppBar(
        title: const Text('Beslenme Analizi'),
        centerTitle: true,
      ),
      body: !state.hasData
          ? _buildEmptyState(theme)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAITipCard(theme),
                  const SizedBox(height: 24),
                  Semantics(
                      header: true,
                      child: Text('Genel Özet',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 12),
                  _buildSummaryGrid(theme, state.history!),
                  const SizedBox(height: 32),
                  Semantics(
                      header: true,
                      child: Text('Haftalık Kalori Trendi',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 12),
                  _buildModernChart(theme, state.history!),
                  const SizedBox(height: 32),
                  Semantics(
                      header: true,
                      child: Text('Makro Dağılımı',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 12),
                  _buildMacroCard(theme, state.history!),
                ],
              ),
            ),
    );
  }

  Widget _buildAITipCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.secondary,
            theme.colorScheme.secondary.withBlue(200)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: [
          BoxShadow(
              color: theme.colorScheme.secondary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('GÜNÜN TAVSİYESİ',
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Bugün protein alımın biraz düşük kalmış. Akşam yemeğinde mercimek veya tavuk tercih ederek dengeliyebilirsin.',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(ThemeData theme, FoodHistoryResult history) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatTile(
            theme,
            'Ortalama',
            '${history.averageDailyCalories.toStringAsFixed(0)}',
            'kcal',
            Icons.speed_rounded,
            AppTheme.primaryColor),
        _buildStatTile(theme, 'Toplam', '${history.totalLogCount}', 'kayıt',
            Icons.inventory_2_outlined, Colors.orange),
      ],
    );
  }

  Widget _buildStatTile(ThemeData theme, String label, String value,
      String unit, IconData icon, Color color) {
    // Parça parça "1850", "kcal", "Ortalama" okumak yerine tek anlamlı
    // cümle: "Ortalama: 1850 kcal".
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label: $value $unit',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(value,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                Text(unit, style: theme.textTheme.bodySmall),
              ],
            ),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildModernChart(ThemeData theme, FoodHistoryResult history) {
    final days = history.dailyLogs.reversed.take(7).toList();

    // Çubuk grafik görsel bir gösterim; ekran okuyucuya günlerin kalori
    // değerleri sözel olarak sunulur, yoksa grafik tamamen erişilemez kalır.
    final spoken = days.reversed
        .map((log) => '${log.date.day} ${_monthName(log.date.month)}: '
            '${log.totalCalories.toStringAsFixed(0)} kalori')
        .join('. ');

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: days.isEmpty
          ? 'Haftalık kalori trendi. Gösterilecek veri yok.'
          : 'Haftalık kalori trendi. $spoken.',
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: days
              .map((log) {
                double heightFactor =
                    (log.totalCalories / 2500).clamp(0.1, 1.0);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 120 * heightFactor,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${log.date.day}/${log.date.month}',
                        style: theme.textTheme.labelSmall),
                  ],
                );
              })
              .toList()
              .reversed
              .toList(),
        ),
      ),
    );
  }

  static String _monthName(int month) => const [
        'Ocak',
        'Şubat',
        'Mart',
        'Nisan',
        'Mayıs',
        'Haziran',
        'Temmuz',
        'Ağustos',
        'Eylül',
        'Ekim',
        'Kasım',
        'Aralık',
      ][month - 1];

  Widget _buildMacroCard(ThemeData theme, FoodHistoryResult history) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: 'Makro dağılımı. Yüzde 30 protein, '
            'yüzde 50 karbonhidrat, yüzde 20 yağ.',
        child: Column(
          children: [
            Row(
              children: [
                _macroIndicator('Protein', 0.3, Colors.green),
                _macroIndicator('Karbon.', 0.5, Colors.orange),
                _macroIndicator('Yağ', 0.2, Colors.red),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: const LinearProgressIndicator(
                  value: 0.7,
                  minHeight: 10,
                  backgroundColor: Color(0xFFF1F5F9)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroIndicator(String label, double val, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${(val * 100).toInt()}%',
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined,
              size: 80, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          const Text('Henüz veri yok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
