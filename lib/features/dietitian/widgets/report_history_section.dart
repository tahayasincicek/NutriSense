import 'package:flutter/material.dart';
import '../models/shared_report_history.dart';

/// Shared visual language for the patient's report archive and delivery cards.
class ReportHistorySection extends StatelessWidget {
  const ReportHistorySection({super.key, required this.items});
  final List<SharedReportHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sent = items.where((item) => item.isDelivered).length;
    final replies = items.where((item) => item.hasReply).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF123E36), Color(0xFF065F46)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.spa_outlined, color: Color(0xFFBDE5D2), size: 20),
            SizedBox(width: 8),
            Flexible(
                child: Text('BESLENME TAKİBİ',
                    style: TextStyle(
                      color: Color(0xFFBDE5D2),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ))),
          ]),
          const SizedBox(height: 14),
          Semantics(
              header: true,
              child: Text('Gönderdiğim Raporlar',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ))),
          const SizedBox(height: 8),
          Text('Paylaşımlarınız ve diyetisyeninizden gelen notlar bir arada.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFD6E9E1),
                height: 1.5,
              )),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1, color: Color(0xFF4D7B69))),
          Wrap(spacing: 28, runSpacing: 16, children: [
            _Metric(value: items.length, label: 'Rapor'),
            _Metric(value: sent, label: 'Gönderildi'),
            _Metric(value: replies, label: 'Yanıt'),
          ]),
        ]),
      ),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(
            child: Text('Paylaşım geçmişi',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700))),
        Text('${items.length} rapor',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant)),
      ]),
      const SizedBox(height: 12),
      if (items.isEmpty)
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Icon(Icons.description_outlined, size: 36, color: colors.primary),
            const SizedBox(height: 14),
            Text('İlk paylaşımınıza hazır', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
                'Beslenme raporunuzu paylaştığınızda gönderim durumu ve '
                'diyetisyeninizin yanıtı burada görünecek.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant, height: 1.5)),
          ]),
        )
      else
        ...items.map((item) => ReportHistoryCard(item: item)),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.1)),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(color: Color(0xFFD6E9E1), fontSize: 12)),
        ],
      );
}

class ReportHistoryCard extends StatelessWidget {
  const ReportHistoryCard({super.key, required this.item});
  final SharedReportHistoryItem item;

  static const _months = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara'
  ];
  String _date(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';
  String get _period {
    final a = item.fromDate;
    final b = item.toDate;
    if (a == b) return _date(a);
    if (a.year == b.year && a.month == b.month) {
      return '${a.day}–${b.day} ${_months[b.month - 1]} ${b.year}';
    }
    return '${_date(a)} – ${_date(b)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final failed = item.status == 'failed';
    final accent = item.isDelivered
        ? (dark ? const Color(0xFF86EFAC) : const Color(0xFF166348))
        : failed
            ? (dark ? const Color(0xFFFDA4AF) : const Color(0xFF9F243B))
            : (dark ? const Color(0xFFFDE68A) : const Color(0xFF805413));
    final statusIcon = item.isDelivered
        ? Icons.check_circle_outline_rounded
        : failed
            ? Icons.error_outline_rounded
            : Icons.schedule_rounded;
    final type = switch (item.reportType) {
      'daily' => 'Günlük rapor',
      'weekly' => 'Haftalık rapor',
      'monthly' => 'Aylık rapor',
      _ => 'Beslenme raporu',
    };
    return Semantics(
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: colors.outlineVariant.withValues(alpha: .65)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .12 : .025),
                blurRadius: 18,
                offset: const Offset(0, 5))
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Icon(Icons.spa_outlined, size: 30, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(type,
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant, letterSpacing: .3)),
                  const SizedBox(height: 5),
                  Text(_period,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700, height: 1.3)),
                ])),
          ]),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, color: accent, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                      child: Text(item.statusLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: accent, fontWeight: FontWeight.w700))),
                ]),
              ),
              Text('${item.recordCount} besin kaydı',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
          if (item.channels.isNotEmpty) ...[
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(
                    height: 1,
                    color: colors.outlineVariant.withValues(alpha: .65))),
            Wrap(
                spacing: 16,
                runSpacing: 10,
                children: item.channels
                    .map(
                      (channel) =>
                          Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                            channel.channel == 'sms'
                                ? Icons.sms_outlined
                                : Icons.mail_outline_rounded,
                            size: 16,
                            color: colors.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(
                                '${channel.channelLabel} · ${channel.statusLabel}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant))),
                      ]),
                    )
                    .toList()),
          ],
          if (item.hasReply) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .055),
                border:
                    Border(left: BorderSide(color: colors.primary, width: 3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 16, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('Diyetisyeninizin notu',
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 10),
                    Text(item.dietitianReply!,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                    if (item.dietitianRepliedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(_date(item.dietitianRepliedAt!),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ]),
            ),
          ],
        ]),
      ),
    );
  }
}
