import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/food_analysis_model.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/navigation_announcer.dart';
import '../state/history_controller.dart';

class FoodHistoryScreen extends ConsumerStatefulWidget {
  const FoodHistoryScreen({super.key, this.onScanRequested});

  final VoidCallback? onScanRequested;

  @override
  ConsumerState<FoodHistoryScreen> createState() => _FoodHistoryScreenState();
}

class _FoodHistoryScreenState extends ConsumerState<FoodHistoryScreen> {
  late final AccessibilityService _accessibility;
  late final NavigationAnnouncer _announcer;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _announcer = ref.read(navigationAnnouncerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcer.announceScreen(AppScreen.history);
      ref.read(historyControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beslenme Günlüğü'),
        actions: [
          Semantics(
            label: 'Erişilebilir tarih seçiciyi aç',
            button: true,
            child: IconButton(
              key: const Key('history_date_picker'),
              icon: const Icon(Icons.calendar_month),
              tooltip: 'Tarih seç',
              onPressed: _pickDate,
            ),
          ),
          Semantics(
            label: 'Günlük özetini sesli dinle',
            button: true,
            child: IconButton(
              key: const Key('history_speak_summary'),
              icon: const Icon(Icons.record_voice_over),
              tooltip: 'Özeti dinle',
              onPressed: state.hasData ? () => _speakSummary(state) : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _PeriodSelector(
            selected: state.period,
            onSelected: (period) =>
                ref.read(historyControllerProvider.notifier).setPeriod(period),
          ),
          Expanded(child: _buildContent(state)),
        ],
      ),
    );
  }

  Widget _buildContent(HistoryState state) {
    if (state.authRequired) return _buildAuthRequired();
    if (state.status == HistoryStatus.initial ||
        (state.status == HistoryStatus.loading && !state.hasData)) {
      return Center(
        child: Semantics(
          label: 'Beslenme geçmişi yükleniyor',
          liveRegion: true,
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (state.status == HistoryStatus.error && !state.hasData) {
      return _buildError(state);
    }
    if (state.status == HistoryStatus.empty) return _buildEmpty();
    return _buildHistory(state);
  }

  Widget _buildAuthRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          label: 'Oturum gerekli. Giriş ekranına yönlendiriliyorsunuz.',
          child: const Text(
            'Beslenme günlüğünü görmek için oturum açın.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildError(HistoryState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          label: 'Geçmiş yüklenemedi. ${state.message}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64),
              const SizedBox(height: 16),
              Text(state.message ?? 'Geçmiş yüklenemedi.'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('history_retry'),
                onPressed: () =>
                    ref.read(historyControllerProvider.notifier).load(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Semantics(
        liveRegion: true,
        label:
            'Seçilen dönemde onaylı besin kaydı yok. Besin taramaya geçebilirsiniz.',
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant_menu, size: 72),
              const SizedBox(height: 16),
              const Text('Seçilen dönemde kayıt yok'),
              const SizedBox(height: 8),
              const Text('Onayladığınız taramalar burada görünür.'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                key: const Key('history_scan_action'),
                onPressed: widget.onScanRequested,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Besin tara'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(HistoryState state) {
    final history = state.history!;
    return RefreshIndicator(
      onRefresh: ref.read(historyControllerProvider.notifier).refresh,
      child: ListView(
        key: const Key('history_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (state.isOffline) _OfflineBanner(state: state),
          if (state.isRefreshing) const LinearProgressIndicator(),
          _PeriodSummary(history: history, period: state.period),
          for (final day in history.dailyLogs) ...[
            _DailySummaryCard(day: day),
            for (final entry in day.foods)
              _FoodLogCard(
                entry: entry,
                onListen: () => _accessibility.speak(
                  entry.semanticLabel,
                  priority: TtsPriority.normal,
                ),
                onEdit: () => _showEditDialog(entry),
                onChangeMeal: () => _showMealDialog(entry),
                onDelete: () => _confirmAndDelete(entry),
              ),
          ],
          if (history.hasMore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                key: const Key('history_load_more'),
                onPressed: state.isRefreshing
                    ? null
                    : ref.read(historyControllerProvider.notifier).loadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Daha eski günleri yükle'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final state = ref.read(historyControllerProvider);
    final selected = await showDatePicker(
      context: context,
      initialDate: state.anchorDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Günlük kayıt tarihini seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (selected != null && mounted) {
      await ref.read(historyControllerProvider.notifier).selectDate(selected);
    }
  }

  void _speakSummary(HistoryState state) {
    final history = state.history!;
    _accessibility.speak(
      '${state.period.label} özet. ${history.totalLogCount} onaylı kayıt. '
      'Toplam ${history.totalCalories.toStringAsFixed(0)} kalori. '
      'Günlük ortalama ${history.averageDailyCalories.toStringAsFixed(0)} kalori. '
      'Değerler tahminidir ve tıbbi öneri değildir.',
      priority: TtsPriority.high,
    );
  }

  Future<void> _showEditDialog(FoodLogEntry entry) async {
    final name = TextEditingController(text: entry.foodNameTr);
    final portion =
        TextEditingController(text: entry.portionG.toStringAsFixed(0));
    var mealType = entry.mealType;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${entry.foodNameTr} kaydını düzelt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Besin adı etiketi düzeltilir; besin kaynağı sessizce değiştirilmez.',
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('history_edit_name'),
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Türkçe besin adı'),
                ),
                TextField(
                  key: const Key('history_edit_portion'),
                  controller: portion,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Onaylı porsiyon, gram'),
                ),
                DropdownButtonFormField<String>(
                  key: const Key('history_edit_meal'),
                  initialValue: mealType,
                  decoration: const InputDecoration(labelText: 'Öğün türü'),
                  items: _mealItems,
                  onChanged: (value) => setDialogState(() => mealType = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              key: const Key('history_edit_save'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !mounted) return;
    final grams = double.tryParse(portion.text.replaceAll(',', '.'));
    if (grams == null || !grams.isFinite || grams <= 0 || grams > 2000) {
      _showMessage('Porsiyon 0 ile 2000 gram arasında olmalıdır.');
      return;
    }
    final result =
        await ref.read(historyControllerProvider.notifier).updateEntry(
              logId: entry.id,
              foodNameTr: name.text.trim(),
              portionGrams: grams,
              mealType: mealType,
            );
    if (mounted) _showMessage(result.message);
  }

  Future<void> _showMealDialog(FoodLogEntry entry) async {
    final meal = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Öğün türünü seçin'),
        children: _mealItems
            .map((item) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, item.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text((item.child as Text).data!),
                  ),
                ))
            .toList(),
      ),
    );
    if (meal == null || !mounted) return;
    final result =
        await ref.read(historyControllerProvider.notifier).updateEntry(
              logId: entry.id,
              mealType: meal,
            );
    if (mounted) _showMessage(result.message);
  }

  Future<void> _confirmAndDelete(FoodLogEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: Text(
          '${entry.foodNameTr} kaydını silmek istiyor musunuz? İşlem kısa süre içinde geri alınabilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('history_delete_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref
        .read(historyControllerProvider.notifier)
        .deleteEntry(entry.id);
    if (!mounted) return;
    if (!result.isSuccess) {
      _showMessage(result.message);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Kayıt silindi.'),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () async {
            final restored = await ref
                .read(historyControllerProvider.notifier)
                .restoreEntry(entry.id);
            if (mounted) _showMessage(restored.message);
          },
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    _accessibility.speak(message, priority: TtsPriority.normal);
  }
}

const _mealItems = [
  DropdownMenuItem(value: 'kahvalti', child: Text('Kahvaltı')),
  DropdownMenuItem(value: 'ogle', child: Text('Öğle')),
  DropdownMenuItem(value: 'aksam', child: Text('Akşam')),
  DropdownMenuItem(value: 'atistirmalik', child: Text('Atıştırmalık')),
];

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final HistoryPeriod selected;
  final ValueChanged<HistoryPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: HistoryPeriod.values
            .map((period) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Semantics(
                      selected: selected == period,
                      button: true,
                      label: '${period.label} görünüm',
                      child: ChoiceChip(
                        label: Text(period.label),
                        selected: selected == period,
                        onSelected: (_) => onSelected(period),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.state});

  final HistoryState state;

  @override
  Widget build(BuildContext context) {
    final cachedAt = state.cachedAt?.toLocal();
    final time = cachedAt == null
        ? ''
        : ' Son güncelleme ${cachedAt.hour.toString().padLeft(2, '0')}:'
            '${cachedAt.minute.toString().padLeft(2, '0')}.';
    return Semantics(
      liveRegion: true,
      label: 'Çevrim dışı önbellek gösteriliyor.$time',
      child: Container(
        color: Colors.amber.shade100,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.cloud_off),
            const SizedBox(width: 8),
            Expanded(child: Text('Çevrim dışı kayıtlar gösteriliyor.$time')),
          ],
        ),
      ),
    );
  }
}

class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({required this.history, required this.period});

  final FoodHistoryResult history;
  final HistoryPeriod period;

  @override
  Widget build(BuildContext context) {
    final label =
        '${period.label} özet: ${history.totalLogCount} onaylı kayıt, '
        'toplam ${history.totalCalories.toStringAsFixed(0)} kalori, '
        'günlük ortalama ${history.averageDailyCalories.toStringAsFixed(0)} kalori. '
        'Besin değerleri tahminidir; tıbbi öneri değildir.';
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(
        child: Card(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${period.label} takip özeti',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('${history.totalLogCount} kayıt • '
                    '${history.totalCalories.toStringAsFixed(0)} kcal'),
                Text('Günlük ortalama '
                    '${history.averageDailyCalories.toStringAsFixed(0)} kcal'),
                const Text('Tahmini bilgi; tıbbi öneri değildir.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({required this.day});

  final DailyLog day;

  @override
  Widget build(BuildContext context) {
    final targetText = day.calorieTarget > 0
        ? day.remainingCalories >= 0
            ? 'Kullanıcının takip hedefinde '
                '${day.remainingCalories.toStringAsFixed(0)} kcal alan kaldı.'
            : 'Kullanıcının takip hedefinin '
                '${day.remainingCalories.abs().toStringAsFixed(0)} kcal üzerinde. '
                'Bu tıbbi değerlendirme değildir.'
        : 'Kişisel takip hedefi belirlenmemiş.';
    final date = '${day.date.day.toString().padLeft(2, '0')}.'
        '${day.date.month.toString().padLeft(2, '0')}.${day.date.year}';
    final semantics = '$date özeti. ${day.mealCount} kayıt, '
        '${day.totalCalories.toStringAsFixed(0)} kalori, '
        '${day.totalProtein.toStringAsFixed(1)} gram protein, '
        '${day.totalCarbs.toStringAsFixed(1)} gram karbonhidrat, '
        '${day.totalFat.toStringAsFixed(1)} gram yağ. $targetText';
    return Semantics(
      label: semantics,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                  '${day.totalCalories.toStringAsFixed(0)} kcal • '
                  '${day.mealCount} kayıt',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  )),
              Text(
                  'P ${day.totalProtein.toStringAsFixed(1)} g • '
                  'K ${day.totalCarbs.toStringAsFixed(1)} g • '
                  'Y ${day.totalFat.toStringAsFixed(1)} g',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Text(targetText, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodLogCard extends StatelessWidget {
  const _FoodLogCard({
    required this.entry,
    required this.onListen,
    required this.onEdit,
    required this.onChangeMeal,
    required this.onDelete,
  });

  final FoodLogEntry entry;
  final VoidCallback onListen;
  final VoidCallback onEdit;
  final VoidCallback onChangeMeal;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('food_log_${entry.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Semantics(
              label: entry.semanticLabel,
              container: true,
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.restaurant, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.foodNameTr,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('${entry.portionLabel} • ${entry.mealTypeTr}'),
                          Text(
                              '${entry.nutrients.protein.toStringAsFixed(1)} g protein • '
                              '${entry.nutrients.carbs.toStringAsFixed(1)} g karbonhidrat • '
                              '${entry.nutrients.fat.toStringAsFixed(1)} g yağ'),
                          Text('${entry.localDateTimeLabel} • '
                              '${entry.recognitionSourceTr}'),
                          Text(entry.statusLabel),
                        ],
                      ),
                    ),
                    Text('${entry.calories.toStringAsFixed(0)} kcal'),
                  ],
                ),
              ),
            ),
            const Divider(),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 4,
              children: [
                IconButton(
                  key: Key('listen_${entry.id}'),
                  tooltip: '${entry.foodNameTr} kaydını dinle',
                  onPressed: onListen,
                  icon: const Icon(Icons.volume_up),
                ),
                IconButton(
                  key: Key('edit_${entry.id}'),
                  tooltip: '${entry.foodNameTr} kaydını düzelt',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  key: Key('meal_${entry.id}'),
                  tooltip: '${entry.foodNameTr} öğün türünü değiştir',
                  onPressed: onChangeMeal,
                  icon: const Icon(Icons.schedule),
                ),
                IconButton(
                  key: Key('delete_${entry.id}'),
                  tooltip: '${entry.foodNameTr} kaydını sil',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
