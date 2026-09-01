import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/turkish_number_parser.dart';
import '../../../shared/widgets/accessible_number_dialog.dart';
import '../state/water_provider.dart';

class ActivityTrackerScreen extends ConsumerWidget {
  const ActivityTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activityProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Sağlık & Aktivite'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepCounter(context, theme, state),
            const SizedBox(height: 24),
            _buildMoodSelector(context, theme, state, ref),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildSleepCard(context, theme, state, ref)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildWaterMiniCard(context, theme, state, ref)),
              ],
            ),
            const SizedBox(height: 24),
            _buildMedicationCard(context, theme, state, ref),
            const SizedBox(height: 24),
            _buildWeightCard(context, theme, state, ref),
            const SizedBox(height: 32),
            Text('Başarımlar ve Rozetler',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildBadgeList(state),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCounter(
      BuildContext context, ThemeData theme, ActivityState state) {
    return Semantics(
      container: true,
      label:
          'Adım Takibi. Hedef: ${state.stepGoal} adım. Atılan adım: ${state.steps}. Yüzde ${(state.stepProgress * 100).toInt()} tamamlandı.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border:
                Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondaryColor.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Günlük Adım', style: theme.textTheme.titleMedium),
                      Text('${state.steps}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          )),
                    ],
                  ),
                  const Icon(Icons.directions_run_rounded,
                      size: 48, color: AppTheme.secondaryColor),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: state.stepProgress.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.secondaryColor),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Hedef: ${state.stepGoal} adım',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleepCard(BuildContext context, ThemeData theme,
      ActivityState state, WidgetRef ref) {
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: 'Uyku Takibi. ${state.sleepHours} saat. '
          'Hedefin yüzde ${(state.sleepProgress * 100).toInt()} tamamlandı.',
      hint: 'Uyku süresi girmek için çift dokunun',
      onTap: () => _showSleepInputDialog(context, ref, state),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          key: const Key('sleep_card'),
          onTap: () => _showSleepInputDialog(context, ref, state),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border:
                  Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bedtime_rounded,
                        color: Colors.indigo, size: 28),
                    const Spacer(),
                    Icon(Icons.add_circle_outline_rounded,
                        size: 20, color: theme.colorScheme.outline),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Uyku', style: theme.textTheme.titleSmall),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text('${state.sleepHours}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const Text(' sa', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.sleepProgress.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: Colors.indigo.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation(Colors.indigo),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaterMiniCard(BuildContext context, ThemeData theme,
      ActivityState state, WidgetRef ref) {
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: 'Su Takibi. ${state.consumedWater} mililitre içildi. '
          'Hedefin yüzde ${(state.waterProgress * 100).toInt()} tamamlandı.',
      hint: 'Bir bardak su, 200 mililitre eklemek için çift dokunun',
      onTap: () => _addWater(context, ref),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          key: const Key('water_card'),
          onTap: () => _addWater(context, ref),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border:
                  Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop_rounded,
                        color: AppTheme.primaryColor, size: 28),
                    const Spacer(),
                    Icon(Icons.add_circle_outline_rounded,
                        size: 20, color: theme.colorScheme.outline),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Su', style: theme.textTheme.titleSmall),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text('${state.consumedWater}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const Text(' ml', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.waterProgress.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bir bardak (200 ml) su ekler ve sonucu sesli bildirir.
  void _addWater(BuildContext context, WidgetRef ref) {
    ref.read(activityProvider.notifier).addWater(200);
    AccessibilityUtils.lightHaptic();
    final total = ref.read(activityProvider).consumedWater;
    ref.read(accessibilityServiceProvider).speak(
          'Bir bardak su eklendi. Toplam $total mililitre.',
          priority: TtsPriority.high,
        );
  }

  Widget _buildMoodSelector(BuildContext context, ThemeData theme,
      ActivityState state, WidgetRef ref) {
    final moods = [
      {'icon': '😊', 'label': 'Mutlu'},
      {'icon': '😐', 'label': 'Normal'},
      {'icon': '😔', 'label': 'Üzgün'},
      {'icon': '😴', 'label': 'Yorgun'},
      {'icon': '🤩', 'label': 'Enerjik'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bugün nasıl hissediyorsun?',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: moods.map((m) {
              final isSelected = state.currentMood == m['label'];
              return Semantics(
                button: true,
                selected: isSelected,
                label: '${m['label']} hissediyorum',
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(activityProvider.notifier)
                        .setMood(m['label'] as String);
                    AccessibilityUtils.lightHaptic();
                  },
                  child: ExcludeSemantics(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.transparent),
                      ),
                      child: Text(m['icon']!,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(BuildContext context, ThemeData theme,
      ActivityState state, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Semantics(
                  header: true,
                  child: Text('İlaç & Takviye',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
              IconButton(
                tooltip: 'Takviye ekle',
                onPressed: () => _showMedicationDialog(context, ref),
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.medications.isEmpty)
            Text(
              'Takip etmek istediğiniz ilaç veya takviyeyi ekleyin.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ...state.medications.map((med) => _buildMedItem(context, ref, med)),
        ],
      ),
    );
  }

  Widget _buildMedItem(
      BuildContext context, WidgetRef ref, MedicationModel med) {
    void toggle() {
      ref.read(activityProvider.notifier).toggleMedication(med.name);
      AccessibilityUtils.lightHaptic();
      ref.read(accessibilityServiceProvider).speak(
            med.isTaken
                ? '${med.name} alınmadı olarak işaretlendi.'
                : '${med.name} alındı olarak işaretlendi.',
            priority: TtsPriority.high,
          );
    }

    return Semantics(
      // Onay kutusu olarak sunulur: ekran okuyucu "işaretli/işaretsiz"
      // durumunu kendisi duyurur.
      checked: med.isTaken,
      inMutuallyExclusiveGroup: false,
      excludeSemantics: true,
      label: '${med.name}, ${med.schedule}',
      hint: med.isTaken
          ? 'Alınmadı olarak işaretlemek için çift dokunun'
          : 'Alındı olarak işaretlemek için çift dokunun',
      onTap: toggle,
      child: InkWell(
        key: Key('med_${med.name}'),
        onTap: toggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                  med.isTaken
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: med.isTaken ? AppTheme.primaryColor : Colors.grey,
                  size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(med.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration:
                            med.isTaken ? TextDecoration.lineThrough : null)),
              ),
              const SizedBox(width: 8),
              Text(med.schedule,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightCard(BuildContext context, ThemeData theme,
      ActivityState state, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Kilo Takibi', style: theme.textTheme.titleMedium),
              IconButton(
                  onPressed: () => _showWeightInputDialog(context, ref),
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: AppTheme.primaryColor)),
            ],
          ),
          if (!state.hasWeight)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Henüz kilo ölçümü eklemediniz. Sağ üstteki artı ile '
                'ilk ölçümünüzü kaydedin.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(state.currentWeight!.toStringAsFixed(1),
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Text('kg', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: state.weightHistory.map((w) {
                return Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                      child: Text('${w.toInt()}',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold))),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeList(ActivityState state) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: state.badges.length,
        itemBuilder: (context, index) {
          final badge = state.badges[index];
          return Semantics(
            label: '${badge.title} rozeti. ${badge.description}. '
                '${badge.isUnlocked ? 'Kazanıldı' : 'Henüz kazanılmadı'}',
            child: ExcludeSemantics(
              child: Container(
                width: 90,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: badge.isUnlocked
                      ? Colors.white
                      : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: badge.isUnlocked
                          ? AppTheme.primaryColor.withOpacity(0.3)
                          : Colors.transparent),
                  boxShadow: badge.isUnlocked
                      ? [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10)
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: badge.isUnlocked ? 1.0 : 0.3,
                      child: Text(badge.icon,
                          style: const TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(height: 4),
                    Text(badge.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color:
                                badge.isUnlocked ? Colors.black : Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Takip edilecek yeni bir ilaç veya takviye ekler.
  Future<void> _showMedicationDialog(
      BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final scheduleController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Takviye ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              textField: true,
              label: 'İlaç veya takviye adı',
              child: TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Ad'),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              textField: true,
              label: 'Kullanım zamanı',
              child: TextField(
                controller: scheduleController,
                decoration: const InputDecoration(
                  labelText: 'Zaman',
                  hintText: 'Örnek: Sabah - Tok',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    final name = nameController.text.trim();
    final schedule = scheduleController.text.trim();
    nameController.dispose();
    scheduleController.dispose();
    if (saved != true || name.isEmpty || !context.mounted) return;
    ref.read(activityProvider.notifier).addMedication(name, schedule);
    ref.read(accessibilityServiceProvider).speak(
          '$name takip listesine eklendi.',
          priority: TtsPriority.high,
        );
  }

  Future<void> _showWeightInputDialog(
      BuildContext context, WidgetRef ref) async {
    final value = await showAccessibleNumberDialog(
      context: context,
      title: 'Kilo Kaydet',
      fieldLabel: 'Kilo',
      suffix: 'kg',
      spokenUnit: 'kilogram',
      min: 20,
      max: 400,
      step: 0.5,
      initialValue: ref.read(activityProvider).currentWeight,
      fieldKey: const Key('weight_input'),
    );
    if (value == null || !context.mounted) return;
    ref.read(activityProvider.notifier).updateWeight(value);
    ref.read(accessibilityServiceProvider).speak(
          'Kilo ${speakableNumber(value)} kilogram olarak kaydedildi.',
          priority: TtsPriority.high,
        );
  }

  Future<void> _showSleepInputDialog(
    BuildContext context,
    WidgetRef ref,
    ActivityState state,
  ) async {
    final value = await showAccessibleNumberDialog(
      context: context,
      title: 'Uyku Süresi',
      fieldLabel: 'Uyku süresi',
      suffix: 'saat',
      spokenUnit: 'saat',
      min: 0,
      max: 24,
      step: 0.5,
      initialValue: state.sleepHours,
      fieldKey: const Key('sleep_input'),
    );
    if (value == null || !context.mounted) return;
    ref.read(activityProvider.notifier).setSleep(value);
    ref.read(accessibilityServiceProvider).speak(
          'Uyku süresi ${speakableNumber(value)} saat olarak kaydedildi.',
          priority: TtsPriority.high,
        );
  }
}
