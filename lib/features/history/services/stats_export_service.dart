// =============================================================================
// lib/features/history/services/stats_export_service.dart
// NutriSense — Beslenme İstatistik Dışa Aktarma Servisi
//
// CSV formatında beslenme raporu oluşturma.
// share_plus ile paylaşma desteği.
// =============================================================================

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/models/food_analysis_model.dart';

/// CSV dışa aktarma servisi
class StatsExportService {
  /// Yemek geçmişini CSV olarak dışa aktar
  static Future<String> exportToCSV(FoodHistoryResult history) async {
    final buffer = StringBuffer();

    // CSV başlık satırı
    buffer.writeln('Tarih,Öğün,Besin Adı,Porsiyon (g),Kalori (kcal),'
        'Protein (g),Karbonhidrat (g),Yağ (g),Lif (g)');

    for (final dailyLog in history.dailyLogs) {
      final dateStr =
          '${dailyLog.date.year}-${dailyLog.date.month.toString().padLeft(2, '0')}-${dailyLog.date.day.toString().padLeft(2, '0')}';

      for (final entry in dailyLog.foods) {
        final mealType = entry.mealType ?? 'Belirtilmemiş';
        final foodName =
            _escapeCSV(entry.foodNameTr ?? entry.foodName ?? 'Bilinmeyen');
        final portion = entry.portionG.toStringAsFixed(1);
        final calories = entry.calories.toStringAsFixed(1);
        final protein = entry.nutrients.protein.toStringAsFixed(1);
        final carbs = entry.nutrients.carbs.toStringAsFixed(1) ?? '-';
        final fat = entry.nutrients.fat.toStringAsFixed(1) ?? '-';
        final fiber = entry.nutrients.fiber.toStringAsFixed(1) ?? '-';

        buffer.writeln(
            '$dateStr,$mealType,$foodName,$portion,$calories,$protein,$carbs,$fat,$fiber');
      }
    }

    // Özet satırı
    buffer.writeln();
    buffer.writeln('ÖZET');
    buffer.writeln(
        'Toplam Gün,${history.totalDays}');
    buffer.writeln(
        'Toplam Kalori,${history.totalCalories.toStringAsFixed(0)}');
    buffer.writeln(
        'Günlük Ortalama Kalori,${history.averageDailyCalories.toStringAsFixed(0)}');
    buffer.writeln('Toplam Kayıt,${history.totalLogCount}');

    return buffer.toString();
  }

  /// CSV dosyası oluştur ve paylaş
  static Future<void> shareCSV(FoodHistoryResult history) async {
    final csvContent = await exportToCSV(history);
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'nutrisense_rapor_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvContent, encoding: const SystemEncoding());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'NutriSense Beslenme Raporu - $fileName',
      text: 'NutriSense beslenme raporum.',
    );
  }

  /// Günlük özet metni oluştur (TTS için)
  static String dailySummaryText(DailyLog dailyLog) {
    final dateStr =
        '${dailyLog.date.day}/${dailyLog.date.month}/${dailyLog.date.year}';
    final buffer = StringBuffer();
    buffer.write('$dateStr tarihli günlük özet. ');
    buffer.write(
        'Toplam ${dailyLog.totalCalories.toStringAsFixed(0)} kalori tüketildi. ');
    buffer.write('${dailyLog.foods.length} besin kaydedildi. ');

    if (dailyLog.foods.isNotEmpty) {
      buffer.write('Besinler: ');
      for (var i = 0; i < dailyLog.foods.length && i < 5; i++) {
        final entry = dailyLog.foods[i];
        final name = entry.foodNameTr ?? entry.foodName;
        final cal = entry.calories.toStringAsFixed(0);
        buffer.write('$name $cal kalori');
        if (i < dailyLog.foods.length - 1 && i < 4) buffer.write(', ');
      }
      if (dailyLog.foods.length > 5) {
        buffer.write(' ve ${dailyLog.foods.length - 5} besin daha');
      }
      buffer.write('.');
    }

    return buffer.toString();
  }

  static String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
