// =============================================================================
// lib/core/utils/accessibility_utils.dart
// NutriSense — Erişilebilirlik Yardımcı Araçları
//
// TalkBack/VoiceOver uyumlu ekran okuyucu duyuruları, haptic feedback,
// odak yönetimi ve semantik etiketleme yardımcıları.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Erişilebilirlik yardımcı sınıfı
/// Ekran okuyucu bildirimleri, haptic feedback ve odak yönetimi sağlar.
class AccessibilityUtils {
  AccessibilityUtils._();

  // ---------------------------------------------------------------------------
  // EKRAN OKUYUCU BİLDİRİMLERİ
  // ---------------------------------------------------------------------------

  /// Ekran okuyucuya anında mesaj duyurur.
  /// TalkBack (Android) ve VoiceOver (iOS) ile uyumludur.
  ///
  /// Örnek: `AccessibilityUtils.announce('Elma tanındı, 78 kalori')`
  static Future<void> announce(String message) async {
    await SemanticsService.announce(message, TextDirection.ltr);
  }

  /// Ekran okuyucuya hata mesajı duyurur (assertive).
  /// Daha yüksek öncelikle okunur.
  static Future<void> announceError(String message) async {
    await SemanticsService.announce(
      'Hata: $message',
      TextDirection.ltr,
    );
  }

  /// Ekran okuyucuya başarı mesajı duyurur.
  static Future<void> announceSuccess(String message) async {
    await SemanticsService.announce(
      'Başarılı: $message',
      TextDirection.ltr,
    );
  }

  /// Sayfa değişikliğini duyurur.
  static Future<void> announcePageChange(String pageName) async {
    await SemanticsService.announce(
      '$pageName sayfasına geçildi',
      TextDirection.ltr,
    );
  }

  // ---------------------------------------------------------------------------
  // HAPTİK GERİ BİLDİRİM
  // ---------------------------------------------------------------------------

  /// Hafif titreşim — buton basımı, navigasyon
  static Future<void> lightHaptic() async {
    await HapticFeedback.lightImpact();
  }

  /// Orta titreşim — başarılı işlem
  static Future<void> mediumHaptic() async {
    await HapticFeedback.mediumImpact();
  }

  /// Ağır titreşim — hata, uyarı
  static Future<void> heavyHaptic() async {
    await HapticFeedback.heavyImpact();
  }

  /// Özel titreşim deseni — başarı (kısa-kısa)
  static Future<void> successHaptic() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      await Vibration.vibrate(pattern: [0, 50, 100, 50]);
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Özel titreşim deseni — hata (uzun)
  static Future<void> errorHaptic() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) {
      await Vibration.vibrate(pattern: [0, 200, 100, 200]);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  // ---------------------------------------------------------------------------
  // ODAK YÖNETİMİ
  // ---------------------------------------------------------------------------

  /// Belirli bir widget'a odaklanmayı sağlar.
  /// Sayfa geçişlerinde veya dinamik içerik güncellemelerinde kullanılır.
  static void requestFocus(BuildContext context, FocusNode focusNode) {
    FocusScope.of(context).requestFocus(focusNode);
  }

  /// Sayfadaki ilk odaklanılabilir öğeye odaklanır.
  static void focusFirstElement(BuildContext context) {
    FocusScope.of(context).nextFocus();
  }

  /// Odağı kaldırır (klavye kapatma vb.)
  static void unfocus(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  // ---------------------------------------------------------------------------
  // ERİŞİLEBİLİRLİK KONTROL
  // ---------------------------------------------------------------------------

  /// Cihazda ekran okuyucu aktif mi kontrol eder.
  static Future<bool> isScreenReaderActive() async {
    final data = WidgetsBinding.instance.platformDispatcher;
    return data.accessibilityFeatures.accessibleNavigation;
  }

  /// Cihazda büyük metin aktif mi kontrol eder.
  static bool isBoldTextEnabled(BuildContext context) {
    return MediaQuery.of(context).boldText;
  }

  /// Animasyonlar devre dışı mı kontrol eder.
  static bool isReduceMotionEnabled(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Yüksek kontrast aktif mi kontrol eder.
  static bool isHighContrastEnabled(BuildContext context) {
    return MediaQuery.of(context).highContrast;
  }
}

// =============================================================================
// SEMANTİK WRAPPER — Semantics widget'ını kolayca eklemek için yardımcı
// =============================================================================

/// Herhangi bir widget'a semantik etiket eklemek için wrapper.
/// Ekran okuyucular bu etiketleri okur.
///
/// ```dart
/// SemanticWrapper(
///   label: 'Elma, 78 kalori',
///   hint: 'Detayları görmek için çift dokunun',
///   child: FoodCard(...),
/// )
/// ```
class SemanticWrapper extends StatelessWidget {
  final String label;
  final String? hint;
  final String? value;
  final bool isButton;
  final bool isHeader;
  final bool isImage;
  final bool isLink;
  final bool excludeSemantics;
  final VoidCallback? onTap;
  final Widget child;

  const SemanticWrapper({
    super.key,
    required this.label,
    this.hint,
    this.value,
    this.isButton = false,
    this.isHeader = false,
    this.isImage = false,
    this.isLink = false,
    this.excludeSemantics = false,
    this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      value: value,
      button: isButton,
      header: isHeader,
      image: isImage,
      link: isLink,
      excludeSemantics: excludeSemantics,
      onTap: onTap,
      child: child,
    );
  }
}

/// Ekran okuyuculara görünmez ama anlamlı bir duyuru yapmak için widget.
/// Canlı bölge (live region) gibi çalışır.
class AccessibilityAnnouncement extends StatefulWidget {
  final String message;
  final Widget child;

  const AccessibilityAnnouncement({
    super.key,
    required this.message,
    required this.child,
  });

  @override
  State<AccessibilityAnnouncement> createState() =>
      _AccessibilityAnnouncementState();
}

class _AccessibilityAnnouncementState extends State<AccessibilityAnnouncement> {
  @override
  void didUpdateWidget(covariant AccessibilityAnnouncement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      AccessibilityUtils.announce(widget.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: widget.child,
    );
  }
}
