import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../models/dietitian_dashboard_models.dart';
import '../services/dietitian_report_export_service.dart';

/// Danışanın onayıyla gönderilmiş bir raporun tam içeriği.
///
/// Proje raporunun diyetisyene vaat ettiği veri kümesini gösterir: besin adı,
/// miktar, tarih/saat ve kalori değeri. Kayıtlar güne göre gruplanır.
class DietitianReportDetailScreen extends ConsumerStatefulWidget {
  const DietitianReportDetailScreen({
    super.key,
    required this.reportId,
    required this.patientName,
  });

  final String reportId;
  final String patientName;

  @override
  ConsumerState<DietitianReportDetailScreen> createState() =>
      _DietitianReportDetailScreenState();
}

class _DietitianReportDetailScreenState
    extends ConsumerState<DietitianReportDetailScreen> {
  DietitianReportDetail? _detail;
  String? _error;
  bool _loading = true;
  bool _sendingReply = false;
  final _replyController = TextEditingController();

  static const _months = [
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
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.length < 2) return;
    setState(() => _sendingReply = true);
    final result = await ref.read(apiServiceProvider).replyToDietitianReport(
          reportId: widget.reportId,
          reply: text,
        );
    if (!mounted) return;
    setState(() {
      _sendingReply = false;
      if (result.isSuccess) {
        _detail = result.data;
        _replyController.clear();
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(result.isSuccess
            ? 'Cevabınız danışana iletildi.'
            : result.errorMessage ?? 'Cevap kaydedilemedi.'),
      ));
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final result = await ref.read(apiServiceProvider).getDietitianReportDetail(
          reportId: widget.reportId,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _detail = result.data;
      _error = result.isSuccess
          ? null
          : result.errorMessage ?? 'Rapor içeriği alınamadı.';
    });
  }

  String _day(DateTime value) => '${value.day} ${_months[value.month - 1]}';

  String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.patientName),
        actions: [
          IconButton(
            tooltip: 'Raporu CSV olarak paylaş',
            onPressed: _detail == null
                ? null
                : () => DietitianReportExportService.share(_detail!),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Rapor bulunamadı.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              AccessibleButton(
                label: 'Tekrar Dene',
                icon: Icons.refresh_rounded,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;
    final byDay = <DateTime, List<DietitianReportRecord>>{};
    for (final record in detail.records) {
      final key = DateTime(
        record.loggedAt.year,
        record.loggedAt.month,
        record.loggedAt.day,
      );
      byDay.putIfAbsent(key, () => []).add(record);
    }
    final days = byDay.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          _SummaryCard(detail: detail, dayLabel: _day),
          if (detail.patientNote != null) ...[
            const SizedBox(height: 24),
            _PatientNoteCard(
              patientName: detail.patientName,
              note: detail.patientNote!,
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Besin kayıtları',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (detail.records.isEmpty)
            Text(
              'Bu raporda besin kaydı yok.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ...days.map(
              (day) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        _day(day),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...byDay[day]!.map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RecordTile(record: record, time: _time),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (detail.records.isNotEmpty) ...[
            _MacroCard(detail: detail),
            const SizedBox(height: 24),
            _MealTimingCard(detail: detail),
            const SizedBox(height: 24),
          ],
          _ReplySection(
            existingReply: detail.dietitianReply,
            repliedAt: detail.dietitianRepliedAt,
            controller: _replyController,
            sending: _sendingReply,
            onSend: _sendReply,
          ),
          const SizedBox(height: 24),
          Text(
            detail.disclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Danışanın raporla birlikte gönderdiği not veya soru.
///
/// Bu alan hastanın diyetisyene doğrudan soru sorabildiği tek yerdir; bu
/// yüzden raporun hemen altında, ayırt edilebilir bir kartta gösterilir.
/// Rapor dönemindeki makro toplamları.
class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.detail});

  final DietitianReportDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macros = detail.macroTotals;
    final total = macros.protein + macros.carbs + macros.fat;
    final rows = [
      ('Protein', macros.protein, AppTheme.primaryColor),
      ('Karbonhidrat', macros.carbs, AppTheme.warningColor),
      ('Yağ', macros.fat, AppTheme.secondaryColor),
    ];
    return Semantics(
      label: 'Makro dağılımı. Protein ${macros.protein.round()} gram, '
          'karbonhidrat ${macros.carbs.round()} gram, '
          'yağ ${macros.fat.round()} gram.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(theme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Makro dağılımı',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              for (final row in rows) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(row.$1, style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      '${row.$2.round()} g',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: row.$3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total <= 0 ? 0 : row.$2 / total,
                    minHeight: 7,
                    backgroundColor: row.$3.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(row.$3),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Öğünlerin genelde hangi saatte kaydedildiği.
///
/// Öğün düzeni, beslenme takibinde toplam kalori kadar anlamlıdır; bu özet
/// diyetisyene "kahvaltıyı genelde kaçta yapıyor" sorusunu cevaplatır.
class _MealTimingCard extends StatelessWidget {
  const _MealTimingCard({required this.detail});

  final DietitianReportDetail detail;

  String _clock(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = detail.mealTimingSummary;
    final spoken = summary
        .map((item) => '${item.meal} ortalama ${_clock(item.averageMinutes)}, '
            '${item.count} kayıt')
        .join('. ');
    return Semantics(
      label: 'Öğün saatleri. $spoken',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(theme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Öğün saatleri',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              for (final item in summary)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child:
                            Text(item.meal, style: theme.textTheme.bodyMedium),
                      ),
                      Text(
                        'ort. ${_clock(item.averageMinutes)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${item.count} kayıt',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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

/// Diyetisyenin rapora yazdığı cevap ve yazma alanı.
class _ReplySection extends StatelessWidget {
  const _ReplySection({
    required this.existingReply,
    required this.repliedAt,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final String? existingReply;
  final DateTime? repliedAt;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          existingReply == null ? 'Danışana cevap yaz' : 'Cevabınız',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (existingReply != null) ...[
          Semantics(
            label: 'Gönderilmiş cevabınız: $existingReply',
            child: ExcludeSemantics(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(existingReply!, style: theme.textTheme.bodyMedium),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Semantics(
          textField: true,
          label: existingReply == null
              ? 'Danışana cevap yazma alanı'
              : 'Cevabınızı güncelleme alanı',
          child: TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 2000,
            enabled: !sending,
            decoration: InputDecoration(
              hintText: existingReply == null
                  ? 'Örnek: Akşam öğününe protein eklemenizi öneririm.'
                  : 'Yeni cevap önceki cevabın üzerine yazılır',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AccessibleButton(
          label: existingReply == null ? 'Cevabı Gönder' : 'Cevabı Güncelle',
          semanticLabel: 'Cevabı danışana ilet',
          icon: Icons.send_rounded,
          isLoading: sending,
          onPressed: onSend,
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration(ThemeData theme) => BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      border: Border.all(
        color: theme.colorScheme.outline.withValues(alpha: 0.2),
      ),
      boxShadow: [
        BoxShadow(
          color: AppTheme.secondaryColor.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );

class _PatientNoteCard extends StatelessWidget {
  const _PatientNoteCard({required this.patientName, required this.note});

  final String patientName;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$patientName şunu sordu: $note',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Danışanın notu',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(note, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.detail, required this.dayLabel});

  final DietitianReportDetail detail;
  final String Function(DateTime) dayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = '${dayLabel(detail.fromDate)} - ${dayLabel(detail.toDate)}';
    return Semantics(
      label: '$range aralığı. ${detail.recordCount} besin kaydı, '
          'toplam ${detail.totalCalories.round()} kalori, '
          'günlük ortalama ${detail.averageDailyCalories.round()} kalori. '
          '${detail.estimatedPortionCount} kayıtta porsiyon tahminidir.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondaryColor.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(range, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${detail.totalCalories.round()} kcal',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(label: '${detail.recordCount} besin kaydı'),
                  _Chip(
                    label: 'Günlük ort. '
                        '${detail.averageDailyCalories.round()} kcal',
                  ),
                  if (detail.estimatedPortionCount > 0)
                    _Chip(
                      label: '${detail.estimatedPortionCount} tahmini porsiyon',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.time});

  final DietitianReportRecord record;
  final String Function(DateTime) time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final portion = record.portionGrams.round();
    return Semantics(
      label: '${record.foodNameTr}, ${record.mealLabel}, '
          '${time(record.loggedAt)}, $portion gram, '
          '${record.totalCalories.round()} kalori.'
          '${record.portionIsEstimate ? ' Porsiyon tahmini.' : ''}'
          '${record.isCorrected ? ' Danışan tarafından düzeltildi.' : ''}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.foodNameTr,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.mealLabel} - ${time(record.loggedAt)} - '
                      '$portion g${record.portionIsEstimate ? ' (tahmini)' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${record.totalCalories.round()} kcal',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}
