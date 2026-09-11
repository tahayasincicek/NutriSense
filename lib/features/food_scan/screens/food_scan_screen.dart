import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/meal_reminder_service.dart';
import '../../settings/screens/settings_screen.dart';
import '../../auth/state/auth_controller.dart';
import '../../history/state/daily_goal_provider.dart';
import '../../water_tracker/state/water_provider.dart';
import 'camera_screen.dart';
import 'manual_food_entry_screen.dart';
import '../../../shared/widgets/accessible_button.dart';

class FoodScanScreen extends ConsumerStatefulWidget {
  const FoodScanScreen({super.key});

  @override
  ConsumerState<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends ConsumerState<FoodScanScreen> {
  /// Öğün hatırlatmalarının özetini gösterir ve sesli okur.
  void _showReminderSummary() {
    final settings = ref.read(mealReminderServiceProvider).settings;
    final lines = <String>[
      if (settings.breakfastEnabled) 'Kahvaltı ${settings.breakfastHour}:00',
      if (settings.lunchEnabled) 'Öğle ${settings.lunchHour}:00',
      if (settings.dinnerEnabled) 'Akşam ${settings.dinnerHour}:00',
    ];
    final message = lines.isEmpty
        ? 'Açık öğün hatırlatması yok.'
        : 'Öğün hatırlatmaları: ${lines.join(', ')}.';

    ref
        .read(accessibilityServiceProvider)
        .speak(message, priority: TtsPriority.high);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = ref.watch(activityProvider);
    final goal = ref.watch(dailyGoalControllerProvider);
    final name = ref.watch(authControllerProvider).user?.fullName.trim() ?? '';
    final greeting = name.isEmpty ? 'Merhaba' : 'Merhaba, $name';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Semantics(
          header: true,
          label: '$greeting. Harika gidiyorsun.',
          excludeSemantics: true,
          child: Row(
            children: [
              // Dekoratif avatar: ekran okuyucuya sızmaması için üstteki
              // Semantics tarafından dışlanıyor.
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: theme.colorScheme.primary, width: 2),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(greeting,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Harika gidiyorsun!',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showReminderSummary,
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Öğün hatırlatmaları',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ayarlar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Scan Hero Section ---
            _ScanHero(onTap: _openCamera),

            const SizedBox(height: 16),
            AccessibleButton(
              label: 'Manuel Besin Ekle',
              semanticLabel:
                  'Besinleri yazarak veya sesle manuel olarak ekleyin',
              icon: Icons.edit_note_rounded,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ManualFoodEntryScreen()),
                );
              },
            ),

            const SizedBox(height: 24),

            // --- Dashboard Highlights ---
            Row(
              children: [
                Expanded(
                  child: _DashboardMiniCard(
                    title: 'Adım',
                    value: '${activity.steps}',
                    unit: 'adım',
                    icon: Icons.directions_run_rounded,
                    color: AppTheme.secondaryColor,
                    progress: activity.stepProgress,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashboardMiniCard(
                    title: 'Su',
                    value: '${activity.consumedWater}',
                    unit: 'ml',
                    icon: Icons.water_drop_rounded,
                    color: AppTheme.primaryColor,
                    progress: activity.waterProgress,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- Calorie Goal ---
            _buildCalorieProgress(theme, goal),

            const SizedBox(height: 32),

            // --- Daily Tasks ---
            Semantics(
              header: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text('Günün Görevleri',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  const ExcludeSemantics(
                    child: Icon(Icons.auto_awesome_rounded,
                        color: Colors.amber, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildTaskCard(
              theme,
              'Öğle Yemeğini Kaydet',
              'Dengeli bir öğün planla.',
              Icons.restaurant_rounded,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildTaskCard(
              theme,
              '10 Dakika Meditasyon',
              'Zihnini dinlendir.',
              Icons.spa_rounded,
              Colors.purple,
            ),

            const SizedBox(height: 24),
            _buildVoiceTip(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieProgress(ThemeData theme, dynamic goal) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Tek bir duyuru olarak okunur: "Beslenme hedefi. 1200 kalorinin
          // 450 kalorisi tamamlandı." Parça parça okunması anlamsız olurdu.
          Semantics(
            container: true,
            excludeSemantics: true,
            label: 'Beslenme hedefi. '
                '${goal.goalCalories.toStringAsFixed(0)} kalorinin '
                '${goal.consumedCalories.toStringAsFixed(0)} kalorisi tamamlandı.',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text('Beslenme Hedefi',
                      style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${goal.consumedCalories.toStringAsFixed(0)} / ${goal.goalCalories.toStringAsFixed(0)} kcal',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: goal.progress.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
              '${goal.remainingCalories.toStringAsFixed(0)} kcal daha tüketebilirsin.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
      ThemeData theme, String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(desc, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          // Süslemelik işaret: bir şey yapmıyor, bu yüzden dokunulabilir
          // olmamalı. Aksi hâlde ekran okuyucu adsız bir onay kutusu okur ve
          // kullanıcı işe yarayan bir denetim sanır.
          const ExcludeSemantics(
            child:
                Checkbox(value: false, onChanged: null, shape: CircleBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceTip(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sesli Komut İpucu',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text('"Su ekle" veya "Neredeyim?" diye sorabilirsin.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCamera() async {
    await AccessibilityUtils.mediumHaptic();
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CameraScreen()));
  }
}

class _DashboardMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final double progress;
  const _DashboardMiniCard(
      {required this.title,
      required this.value,
      required this.unit,
      required this.icon,
      required this.color,
      required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900, color: color)),
          Text('$unit $title', style: theme.textTheme.labelSmall),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color)),
          ),
        ],
      ),
    );
  }
}

class _ScanHero extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Uygulamanın ana eylemi. Ekran okuyucuya düz bir kutu değil, buton
    // olarak sunulmalı; sabit yükseklik yerine minimum yükseklik kullanıp
    // büyük fontta içeriğin kesilmesini önlüyoruz.
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Hızlı tarama. Besinini tanı.',
      hint: 'Kamerayı yemeğine tutup sonucu dinlemek için çift dokunun',
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 180),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(Icons.camera_alt_rounded,
                      size: 140, color: Colors.white.withValues(alpha: 0.15))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('HIZLI TARAMA',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    Text('Besinini Tanı',
                        style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w900)),
                    Text('Kamerayı yemeğine tut ve sonucu dinle.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
