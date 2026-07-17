// =============================================================================
// lib/shared/widgets/accessible_text.dart
// NutriSense — Erişilebilir Metin Widget'ı
//
// Semantik etiketli, ekran okuyucu uyumlu, otomatik ölçeklenen metin.
// =============================================================================

import 'package:flutter/material.dart';

/// Erişilebilir metin — semanticLabel desteği ile metin gösterimi.
///
/// Normal Text widget'ından farkı:
/// - Otomatik semanticLabel ekleme
/// - Ekran okuyucu için header/label rolü belirleme
/// - maxLines ve overflow koruması
///
/// ```dart
/// AccessibleText(
///   'Günlük Kalori: 1250 kcal',
///   style: theme.textTheme.headlineMedium,
///   semanticLabel: 'Günlük toplam kalori bin iki yüz elli kilokalori',
///   isHeader: true,
/// )
/// ```
class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final String? semanticLabel;
  final bool isHeader;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AccessibleText(
    this.text, {
    super.key,
    this.style,
    this.semanticLabel,
    this.isHeader = false,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  /// Fabrika: büyük başlık
  factory AccessibleText.displayLarge(
    String text, {
    Key? key,
    String? semanticLabel,
    TextAlign? textAlign,
    required BuildContext context,
  }) {
    return AccessibleText(
      text,
      key: key,
      style: Theme.of(context).textTheme.displayLarge,
      semanticLabel: semanticLabel,
      isHeader: true,
      textAlign: textAlign,
    );
  }

  /// Fabrika: başlık
  factory AccessibleText.headline(
    String text, {
    Key? key,
    String? semanticLabel,
    TextAlign? textAlign,
    required BuildContext context,
  }) {
    return AccessibleText(
      text,
      key: key,
      style: Theme.of(context).textTheme.headlineMedium,
      semanticLabel: semanticLabel,
      isHeader: true,
      textAlign: textAlign,
    );
  }

  /// Fabrika: gövde metni
  factory AccessibleText.body(
    String text, {
    Key? key,
    String? semanticLabel,
    TextAlign? textAlign,
    int? maxLines,
    required BuildContext context,
  }) {
    return AccessibleText(
      text,
      key: key,
      style: Theme.of(context).textTheme.bodyMedium,
      semanticLabel: semanticLabel,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }

  /// Fabrika: etiket
  factory AccessibleText.label(
    String text, {
    Key? key,
    String? semanticLabel,
    TextAlign? textAlign,
    required BuildContext context,
  }) {
    return AccessibleText(
      text,
      key: key,
      style: Theme.of(context).textTheme.labelLarge,
      semanticLabel: semanticLabel,
      textAlign: textAlign,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? text,
      header: isHeader,
      excludeSemantics: true,
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        semanticsLabel: semanticLabel,
      ),
    );
  }
}
