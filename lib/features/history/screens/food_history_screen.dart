import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/food_analysis_model.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/contextual_voice_command.dart';
import '../../../shared/services/navigation_announcer.dart';
import '../../../shared/services/stt_service.dart';
import '../state/history_controller.dart';
import 'nutrition_stats_screen.dart';

class FoodHistoryScreen extends ConsumerStatefulWidget {
  const FoodHistoryScreen({super.key, this.onScanRequested});
  final VoidCallback? onScanRequested;

  @override
  ConsumerState<FoodHistoryScreen> createState() => _FoodHistoryScreenState();
}

class _FoodHistoryScreenState extends ConsumerState<FoodHistoryScreen> {
  static const _voiceParser = ContextualVoiceCommandParser();

  late final AccessibilityService _accessibility;
  late final NavigationAnnouncer _announcer;
  late final SttService _stt;

  /// Sesli silme iki adımlıdır; hangi kaydın onay beklediğini burada tutarız.
  final Map<String, bool> _pendingVoiceDelete = {};
  String? _voiceStatus;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _announcer = ref.read(navigationAnnouncerProvider);
    _stt = ref.read(sttServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcer.announceScreen(AppScreen.history);
      ref.read(historyControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Beslenme Günlüğü'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const NutritionStatsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, size: 20),
            onPressed: _pickDate,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _PeriodSelector(
            selected: state.period,
            onSelected: (period) =>
                ref.read(historyControllerProvider.notifier).setPeriod(period),
          ),
          if (state.isOffline && state.message != null)
            _OfflineBanner(message: state.message!, cachedAt: state.cachedAt),
          if (_voiceStatus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _voiceStatus!,
                    style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ),
            ),
          Expanded(child: _buildContent(state)),
        ],
      ),
    );
  }

  Widget _buildContent(HistoryState state) {
    if (state.status == HistoryStatus.loading && !state.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    // Oturum yoksa hata değil, yönlendirici bir mesaj gösterilir.
    if (state.authRequired) return _buildAuthRequired(state);
    if (state.status == HistoryStatus.empty) return _buildEmpty();
    if (state.status == HistoryStatus.error && !state.hasData) {
      return _buildError(state);
    }
    if (state.history == null || state.history!.dailyLogs.isEmpty) {
      return _buildEmpty();
    }
    return _buildHistory(state);
  }

  Widget _buildAuthRequired(HistoryState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 72, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                state.message ??
                    'Beslenme geçmişinizi görmek için lütfen oturum açın.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(HistoryState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              state.message ?? 'Beslenme geçmişi yüklenemedi.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('history_retry'),
              onPressed: () =>
                  ref.read(historyControllerProvider.notifier).load(),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(HistoryState state) {
    final history = state.history!;
    return RefreshIndicator(
      onRefresh: ref.read(historyControllerProvider.notifier).refresh,
      child: ListView.builder(
        key: const Key('history_list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: history.dailyLogs.length + (history.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == history.dailyLogs.length) {
            return _buildLoadMore();
          }
          final day = history.dailyLogs[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DailySummaryCard(day: day),
              ...day.foods.map((entry) => _FoodLogCard(
                    entry: entry,
                    onDelete: () => _confirmAndDelete(entry),
                    onEdit: () => _editEntry(entry),
                    onVoice: () => _voiceCommandFor(entry),
                  )),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(Icons.no_food_rounded,
                    size: 80, color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 16),
              const Text('Seçilen dönemde kayıt yok',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Yediklerini tarayarak başlayabilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('history_scan_action'),
                onPressed: widget.onScanRequested,
                child: const Text('Hemen Tara'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: TextButton(
        onPressed: ref.read(historyControllerProvider.notifier).loadMore,
        child: const Text('Daha Fazla Yükle'),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (selected != null) {
      ref.read(historyControllerProvider.notifier).selectDate(selected);
    }
  }

  Future<void> _confirmAndDelete(FoodLogEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: Text('${entry.foodNameTr} silinsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
            key: const Key('history_delete_confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteWithUndo(entry);
  }

  /// Siler ve geri alma sunar. Yanlış silme, ekran okuyucu kullanıcısı için
  /// düzeltmesi en zor hatalardan biri; geri alma bu yüzden zorunlu.
  Future<void> _deleteWithUndo(FoodLogEntry entry) async {
    final controller = ref.read(historyControllerProvider.notifier);
    final result = await controller.deleteEntry(entry.id);
    if (!mounted) return;
    _accessibility.speak(result.message, priority: TtsPriority.high);
    if (!result.isSuccess) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.foodNameTr} silindi.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () async {
            final restored = await controller.restoreEntry(entry.id);
            if (!mounted) return;
            _accessibility.speak(restored.message, priority: TtsPriority.high);
          },
        ),
      ),
    );
  }

  Future<void> _editEntry(FoodLogEntry entry) async {
    final result = await showDialog<_HistoryEditResult>(
      context: context,
      builder: (_) => _HistoryEditDialog(entry: entry),
    );
    if (result == null || !mounted) return;
    final outcome =
        await ref.read(historyControllerProvider.notifier).updateEntry(
              logId: entry.id,
              foodNameTr: result.foodNameTr,
              portionGrams: result.portionGrams,
            );
    if (!mounted) return;
    _accessibility.speak(outcome.message, priority: TtsPriority.high);
  }

  /// Sesli düzeltme/silme. Silme iki aşamalıdır: önce komut, sonra ayrı bir
  /// "evet" onayı. Tek adımda silmek yanlış tanımada veri kaybı demek olurdu.
  /// Onay sorusunu seslendirir ve hemen ardından yeniden dinlemeye geçer.
  Future<void> _confirmByVoice(FoodLogEntry entry) async {
    await _accessibility.speak(
      'Silmeyi onaylamak için evet deyin.',
      priority: TtsPriority.high,
    );
    if (!mounted) return;
    await _voiceCommandFor(entry);
  }

  Future<void> _voiceCommandFor(FoodLogEntry entry) async {
    final pending = _pendingVoiceDelete[entry.id] ?? false;
    await _stt.startListening(
      onResult: (result) {
        if (!result.isFinal) {
          if (!mounted) return;
          setState(() =>
              _voiceStatus = 'Komut henüz çalıştırılmadı; lütfen tamamlayın.');
          return;
        }
        final intent = _voiceParser.parse(
          result.text,
          context: pending
              ? VoiceInteractionContext.historyDeleteConfirmation
              : VoiceInteractionContext.history,
        );
        if (!mounted) return;
        if (pending) {
          if (intent.action == ContextualVoiceAction.yes) {
            _pendingVoiceDelete.remove(entry.id);
            setState(() => _voiceStatus = null);
            unawaited(_deleteWithUndo(entry));
            return;
          }
          _pendingVoiceDelete.remove(entry.id);
          setState(() => _voiceStatus = 'Silme iptal edildi.');
          return;
        }
        if (intent.action == ContextualVoiceAction.deleteEntry) {
          _pendingVoiceDelete[entry.id] = true;
          setState(() => _voiceStatus = 'Silmeyi onaylamak için evet deyin.');
          // Onay için mikrofon kendiliğinden yeniden açılır; kullanıcıdan
          // göremediği bir düğmeyi bulması istenmez.
          unawaited(_confirmByVoice(entry));
          return;
        }
        setState(
            () => _voiceStatus = 'Komut henüz çalıştırılmadı; anlaşılamadı.');
      },
      onError: (_) {
        if (!mounted) return;
        setState(
            () => _voiceStatus = 'Komut henüz çalıştırılmadı; ses hatası.');
      },
    );
  }
}

/// Çevrim dışı önbellek uyarısı. Kullanıcı gördüğü verinin güncel olmadığını
/// bilmeli; ekran okuyucu için liveRegion olarak duyurulur.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.message, this.cachedAt});

  final String message;
  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stamp = cachedAt == null
        ? ''
        : ' Son güncelleme: '
            '${cachedAt!.toLocal().hour.toString().padLeft(2, '0')}:'
            '${cachedAt!.toLocal().minute.toString().padLeft(2, '0')}.';
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.cloud_off_rounded,
                  size: 20, color: theme.colorScheme.onTertiaryContainer),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$message$stamp',
                style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEditResult {
  const _HistoryEditResult({this.foodNameTr, this.portionGrams});
  final String? foodNameTr;
  final double? portionGrams;
}

/// Kayıt düzeltme diyaloğu. Controller'lar burada tutulur ki diyalog kapanma
/// animasyonu sürerken atılıp "used after disposed" hatası vermesinler.
class _HistoryEditDialog extends StatefulWidget {
  const _HistoryEditDialog({required this.entry});

  final FoodLogEntry entry;

  @override
  State<_HistoryEditDialog> createState() => _HistoryEditDialogState();
}

class _HistoryEditDialogState extends State<_HistoryEditDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.entry.foodNameTr);
  late final TextEditingController _portionController = TextEditingController(
    text: widget.entry.portionValue.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _nameController.dispose();
    _portionController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final portion =
        double.tryParse(_portionController.text.trim().replaceAll(',', '.'));
    Navigator.pop(
      context,
      _HistoryEditResult(
        foodNameTr: name.isEmpty ? null : name,
        portionGrams: (portion != null && portion > 0 && portion <= 2000)
            ? portion
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kaydı Düzelt'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Besin adı düzeltme alanı',
            textField: true,
            child: TextField(
              key: const Key('history_edit_name'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Besin adı'),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Porsiyon gram düzeltme alanı',
            textField: true,
            child: TextField(
              key: const Key('history_edit_portion'),
              controller: _portionController,
              keyboardType: const TextInputType.numberWithOptions(),
              decoration: const InputDecoration(
                labelText: 'Porsiyon (gram)',
                helperText: '0 ile 2000 gram arasında olmalıdır.',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('history_edit_save'),
          onPressed: _save,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final HistoryPeriod selected;
  final ValueChanged<HistoryPeriod> onSelected;
  const _PeriodSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
        ),
        child: Row(
          children: HistoryPeriod.values.map((period) {
            final isSelected = selected == period;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelected(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    period.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DailySummaryCard extends StatelessWidget {
  final DailyLog day;
  const _DailySummaryCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = '${day.date.day} ${_getMonthName(day.date.month)}';

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dateStr,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  '${day.mealCount} kayıt • '
                  '${day.totalCalories.toStringAsFixed(0)} kcal',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Toplam ${day.totalCalories.toStringAsFixed(0)} kcal',
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const names = [
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
      'Aralık'
    ];
    return names[month - 1];
  }
}

class _FoodLogCard extends StatelessWidget {
  final FoodLogEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onVoice;
  const _FoodLogCard({
    required this.entry,
    required this.onDelete,
    required this.onEdit,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Kart, ekran okuyucuya tek anlamlı birim olarak sunulur: parça parça
    // gezinmek yerine "Elma, 150 gram, 78 kalori, ... Kullanıcı onaylı."
    // şeklinde tek seferde okunur. Eylem butonları ayrı düğüm kalır.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: entry.semanticLabel,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getMealColor(entry.mealType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getMealIcon(entry.mealType),
                        color: _getMealColor(entry.mealType)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.foodNameTr,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontSize: 16)),
                      Text('${entry.portionLabel} • ${entry.mealTypeTr}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${entry.calories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            // Kaynak ve doğrulama durumu: kullanıcı kalorinin nereden geldiğini
            // ve onaylanıp onaylanmadığını bilmeli.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Kaynak: ${entry.recognitionSourceTr}',
                    style: theme.textTheme.labelSmall),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(entry.statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: Key('voice_${entry.id}'),
                  icon: const Icon(Icons.mic_none_rounded, size: 20),
                  tooltip: 'Sesli komut',
                  onPressed: onVoice,
                ),
                IconButton(
                  key: Key('edit_${entry.id}'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: '${entry.foodNameTr} kaydını düzelt',
                  onPressed: onEdit,
                ),
                IconButton(
                  key: Key('delete_${entry.id}'),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: '${entry.foodNameTr} kaydını sil',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMealIcon(String type) {
    switch (type) {
      case 'kahvalti':
        return Icons.wb_sunny_outlined;
      case 'ogle':
        return Icons.lunch_dining_outlined;
      case 'aksam':
        return Icons.dark_mode_outlined;
      default:
        return Icons.local_pizza_outlined;
    }
  }

  Color _getMealColor(String type) {
    switch (type) {
      case 'kahvalti':
        return Colors.orange;
      case 'ogle':
        return Colors.blue;
      case 'aksam':
        return Colors.indigo;
      default:
        return Colors.green;
    }
  }
}
