import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dietitian_dashboard_models.dart';

/// Rapor içeriğini CSV olarak dışa aktarır.
///
/// Diyetisyenler kayıtları kendi programlarında incelemek ister; hasta
/// tarafındaki [StatsExportService] ile aynı yaklaşımı izler.
class DietitianReportExportService {
  const DietitianReportExportService._();

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _stamp(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  static String buildCsv(DietitianReportDetail detail) {
    final buffer = StringBuffer();
    buffer.writeln('Danisan,${_escape(detail.patientName)}');
    buffer
        .writeln('Donem,${_stamp(detail.fromDate)} - ${_stamp(detail.toDate)}');
    buffer.writeln();
    buffer.writeln(
      'Tarih,Saat,Ogun,Besin,Miktar (g),Tahmini,Kalori,Protein,Karbonhidrat,Yag',
    );
    for (final record in detail.records) {
      buffer.writeln([
        _stamp(record.loggedAt),
        _time(record.loggedAt),
        _escape(record.mealLabel),
        _escape(record.foodNameTr),
        record.portionGrams.toStringAsFixed(1),
        record.portionIsEstimate ? 'evet' : 'hayir',
        record.totalCalories.toStringAsFixed(1),
        record.protein.toStringAsFixed(1),
        record.carbs.toStringAsFixed(1),
        record.fat.toStringAsFixed(1),
      ].join(','));
    }

    final macros = detail.macroTotals;
    buffer.writeln();
    buffer.writeln('OZET');
    buffer.writeln('Kayit sayisi,${detail.recordCount}');
    buffer.writeln('Toplam kalori,${detail.totalCalories.toStringAsFixed(0)}');
    buffer.writeln(
      'Gunluk ortalama kalori,${detail.averageDailyCalories.toStringAsFixed(0)}',
    );
    buffer.writeln('Toplam protein (g),${macros.protein.toStringAsFixed(1)}');
    buffer
        .writeln('Toplam karbonhidrat (g),${macros.carbs.toStringAsFixed(1)}');
    buffer.writeln('Toplam yag (g),${macros.fat.toStringAsFixed(1)}');
    buffer.writeln(
      'Tahmini porsiyon sayisi,${detail.estimatedPortionCount}',
    );
    if (detail.patientNote != null) {
      buffer.writeln('Danisan notu,${_escape(detail.patientNote!)}');
    }
    if (detail.dietitianReply != null) {
      buffer.writeln('Diyetisyen cevabi,${_escape(detail.dietitianReply!)}');
    }
    return buffer.toString();
  }

  /// CSV dosyasını oluşturup paylaşım penceresini açar.
  static Future<void> share(DietitianReportDetail detail) async {
    final directory = await getTemporaryDirectory();
    final fileName =
        'nutrisense_${_stamp(detail.fromDate)}_${_stamp(detail.toDate)}.csv';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(buildCsv(detail),
        encoding: const SystemEncoding());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'NutriSense beslenme raporu - ${detail.patientName}',
        text: '${detail.patientName} beslenme raporu.',
      ),
    );
  }
}
