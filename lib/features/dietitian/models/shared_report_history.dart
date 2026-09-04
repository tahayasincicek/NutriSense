/// Hastanın diyetisyenine gönderdiği bir raporun geçmiş kaydı.
///
/// Backend uzun süredir bu listeyi veriyordu fakat uygulama hiç okumuyordu;
/// kullanıcı neyi ne zaman paylaştığını ve diyetisyeninin cevap yazıp
/// yazmadığını göremiyordu.
class SharedReportHistoryItem {
  const SharedReportHistoryItem({
    required this.reportId,
    required this.reportType,
    required this.fromDate,
    required this.toDate,
    required this.recordCount,
    required this.status,
    required this.createdAt,
    required this.channels,
    this.dietitianReply,
    this.dietitianRepliedAt,
  });

  final String reportId;
  final String reportType;
  final DateTime fromDate;
  final DateTime toDate;
  final int recordCount;
  final String status;
  final DateTime createdAt;

  /// Gönderim kanalları ve her birinin teslim durumu.
  final List<SharedReportChannel> channels;

  /// Diyetisyenin yazdığı cevap; yoksa null.
  final String? dietitianReply;
  final DateTime? dietitianRepliedAt;

  bool get hasReply => (dietitianReply ?? '').trim().isNotEmpty;

  /// Ekran okuyucuya okunacak özet.
  String get spokenSummary {
    final period = '${_spokenDate(fromDate)} ile ${_spokenDate(toDate)} arası';
    final reply = hasReply ? 'Diyetisyeniniz cevap yazdı.' : 'Henüz cevap yok.';
    return '$period, $recordCount kayıt, durum '
        '${statusLabel.toLowerCase()}. $reply';
  }

  /// Rapor karşı tarafa ulaştı mı.
  bool get isDelivered => status == 'completed' || status == 'sent';

  String get statusLabel {
    switch (status) {
      // Backend tamamlanan gönderim için 'sent' de yazıyor; bu durum
      // karşılanmadığı için kartlarda ham "sent" metni görünüyordu.
      case 'completed':
      case 'sent':
        return 'Gönderildi';
      case 'partial':
        return 'Kısmen gönderildi';
      case 'failed':
        return 'Gönderilemedi';
      case 'pending':
        return 'Gönderiliyor';
      default:
        return status;
    }
  }

  /// Kart üzerinde gösterilen dönem aralığı.
  String get periodLabel => '${_date(fromDate)} - ${_date(toDate)}';

  static String _spokenDate(DateTime value) => _date(value);

  static String _date(DateTime value) =>
      '${value.day}.${value.month}.${value.year}';

  factory SharedReportHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels'] as List<dynamic>? ?? const [];
    return SharedReportHistoryItem(
      reportId: json['report_id'] as String? ?? '',
      reportType: json['report_type'] as String? ?? 'weekly',
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      recordCount: (json['record_count'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      channels: rawChannels
          .map((item) => SharedReportChannel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false),
      dietitianReply: json['dietitian_reply'] as String?,
      dietitianRepliedAt: json['dietitian_replied_at'] == null
          ? null
          : DateTime.parse(json['dietitian_replied_at'] as String),
    );
  }
}

/// Tek bir gönderim kanalının durumu.
class SharedReportChannel {
  const SharedReportChannel({required this.channel, required this.status});

  final String channel;
  final String status;

  String get channelLabel => channel == 'sms' ? 'SMS' : 'E-posta';

  String get statusLabel {
    switch (status) {
      case 'sent':
      case 'delivered':
        return 'iletildi';
      case 'failed':
        return 'iletilemedi';
      default:
        return status;
    }
  }

  factory SharedReportChannel.fromJson(Map<String, dynamic> json) =>
      SharedReportChannel(
        channel: json['channel'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );
}
