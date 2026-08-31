// =============================================================================
// lib/shared/services/meal_reminder_service.dart
// NutriSense — Öğün Hatırlatma Servisi
//
// Sabah/öğle/akşam öğün hatırlatmaları.
// SharedPreferences ile ayarlanabilir saatler.
// TTS ile sesli hatırlatma.
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accessibility_service.dart';

/// Öğün türleri
enum MealType {
  breakfast('Kahvaltı', 'breakfast_reminder_hour', 8, 'breakfast_enabled'),
  lunch('Öğle Yemeği', 'lunch_reminder_hour', 12, 'lunch_enabled'),
  dinner('Akşam Yemeği', 'dinner_reminder_hour', 19, 'dinner_enabled');

  const MealType(this.label, this.hourKey, this.defaultHour, this.enabledKey);
  final String label;
  final String hourKey;
  final int defaultHour;
  final String enabledKey;
}

/// Hatırlatma ayarları
class MealReminderSettings {
  const MealReminderSettings({
    this.breakfastHour = 8,
    this.lunchHour = 12,
    this.dinnerHour = 19,
    this.breakfastEnabled = true,
    this.lunchEnabled = true,
    this.dinnerEnabled = true,
  });

  final int breakfastHour;
  final int lunchHour;
  final int dinnerHour;
  final bool breakfastEnabled;
  final bool lunchEnabled;
  final bool dinnerEnabled;

  int hourFor(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return breakfastHour;
      case MealType.lunch:
        return lunchHour;
      case MealType.dinner:
        return dinnerHour;
    }
  }

  bool isEnabled(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return breakfastEnabled;
      case MealType.lunch:
        return lunchEnabled;
      case MealType.dinner:
        return dinnerEnabled;
    }
  }

  MealReminderSettings copyWith({
    int? breakfastHour,
    int? lunchHour,
    int? dinnerHour,
    bool? breakfastEnabled,
    bool? lunchEnabled,
    bool? dinnerEnabled,
  }) {
    return MealReminderSettings(
      breakfastHour: breakfastHour ?? this.breakfastHour,
      lunchHour: lunchHour ?? this.lunchHour,
      dinnerHour: dinnerHour ?? this.dinnerHour,
      breakfastEnabled: breakfastEnabled ?? this.breakfastEnabled,
      lunchEnabled: lunchEnabled ?? this.lunchEnabled,
      dinnerEnabled: dinnerEnabled ?? this.dinnerEnabled,
    );
  }
}

/// Öğün hatırlatma servisi
class MealReminderService {
  MealReminderService(this._accessibility);

  final AccessibilityService _accessibility;
  Timer? _checkTimer;
  MealReminderSettings _settings = const MealReminderSettings();
  final Set<String> _announcedToday = {};

  MealReminderSettings get settings => _settings;

  /// Servisi başlat ve ayarları yükle
  Future<void> initialize() async {
    await _loadSettings();
    _startPeriodicCheck();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = MealReminderSettings(
      breakfastHour: prefs.getInt(MealType.breakfast.hourKey) ??
          MealType.breakfast.defaultHour,
      lunchHour:
          prefs.getInt(MealType.lunch.hourKey) ?? MealType.lunch.defaultHour,
      dinnerHour:
          prefs.getInt(MealType.dinner.hourKey) ?? MealType.dinner.defaultHour,
      breakfastEnabled: prefs.getBool(MealType.breakfast.enabledKey) ?? true,
      lunchEnabled: prefs.getBool(MealType.lunch.enabledKey) ?? true,
      dinnerEnabled: prefs.getBool(MealType.dinner.enabledKey) ?? true,
    );
  }

  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    // Her dakika kontrol et
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkReminders();
    });
    // Bir kere hemen kontrol et
    _checkReminders();
  }

  void _checkReminders() {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';

    // Gün değiştiyse eski duyuruları temizle
    _announcedToday.removeWhere((key) => !key.startsWith(todayKey));

    for (final meal in MealType.values) {
      if (!_settings.isEnabled(meal)) continue;

      final mealHour = _settings.hourFor(meal);
      final mealKey = '$todayKey-${meal.name}';

      // Tam saatte veya saati 5 dk geçmişse ve henüz duyurulmamışsa
      if (now.hour == mealHour &&
          now.minute <= 5 &&
          !_announcedToday.contains(mealKey)) {
        _announcedToday.add(mealKey);
        _announceReminder(meal);
      }
    }
  }

  void _announceReminder(MealType meal) {
    final message = '${meal.label} zamanı! '
        'Besininizi kaydetmek için tara diyebilir veya '
        '"tara" diyerek sesli komut verebilirsiniz.';
    _accessibility.speak(message, priority: TtsPriority.high);
  }

  /// Öğün saatini güncelle
  Future<void> setMealHour(MealType meal, int hour) async {
    final clamped = hour.clamp(0, 23);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(meal.hourKey, clamped);
    await _loadSettings();
  }

  /// Öğün hatırlatmasını aç/kapat
  Future<void> setMealEnabled(MealType meal, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(meal.enabledKey, enabled);
    await _loadSettings();
  }

  void dispose() {
    _checkTimer?.cancel();
  }
}

final mealReminderServiceProvider = Provider<MealReminderService>((ref) {
  final accessibility = ref.read(accessibilityServiceProvider);
  final service = MealReminderService(accessibility);
  ref.onDispose(service.dispose);
  return service;
});
