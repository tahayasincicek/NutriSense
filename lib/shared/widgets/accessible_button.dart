// =============================================================================
// lib/shared/widgets/accessible_button.dart
// NutriSense — Erişilebilir Buton Widget'ı
//
// WCAG hedeflerini gözeten büyük dokunma alanı, semantik etiket, haptic feedback
// ve TTS geri bildirimi olan özel buton.
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/accessibility_utils.dart';

/// Erişilebilir buton — tüm butonlar bu widget üzerinden oluşturulmalı.
///
/// Özellikler:
/// - Minimum 48×48dp dokunma alanı (WCAG 2.5.5)
/// - Semantik etiket (TalkBack/VoiceOver)
/// - Basımda haptic feedback
/// - Opsiyonel TTS geri bildirimi
///
/// ```dart
/// AccessibleButton(
///   label: 'Besin Tara',
///   semanticLabel: 'Kamerayı açarak besin tarama başlatır',
///   icon: Icons.camera_alt,
///   onPressed: () => startScan(),
/// )
/// ```
class AccessibleButton extends StatelessWidget {
  /// Buton üzerinde görünen metin
  final String label;

  /// Ekran okuyucu tarafından okunacak açıklama
  final String? semanticLabel;

  /// Ekran okuyucu tarafından okunacak ipucu
  final String? semanticHint;

  /// Buton ikonu (opsiyonel)
  final IconData? icon;

  /// Basılma olayı
  final VoidCallback? onPressed;

  /// Uzun basma olayı
  final VoidCallback? onLongPress;

  /// Buton tipi: filled, outlined, text
  final AccessibleButtonType type;

  /// Genişlik tam ekran mı?
  final bool fullWidth;

  /// Yükleniyor durumu
  final bool isLoading;

  /// Haptic feedback etkin mi?
  final bool enableHaptic;

  /// Özel arka plan rengi
  final Color? backgroundColor;

  /// Özel ön plan rengi
  final Color? foregroundColor;

  const AccessibleButton({
    super.key,
    required this.label,
    this.semanticLabel,
    this.semanticHint,
    this.icon,
    this.onPressed,
    this.onLongPress,
    this.type = AccessibleButtonType.filled,
    this.fullWidth = true,
    this.isLoading = false,
    this.enableHaptic = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticLabel ?? label,
      hint: semanticHint ?? 'Etkinleştirmek için çift dokunun',
      button: true,
      enabled: onPressed != null && !isLoading,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: fullWidth ? double.infinity : A11yConstants.minTouchTarget,
          minHeight: A11yConstants.minTouchTarget + 8,
        ),
        child: _buildButton(context, theme),
      ),
    );
  }

  Widget _buildButton(BuildContext context, ThemeData theme) {
    final effectiveOnPressed = isLoading
        ? null
        : () {
            if (enableHaptic) AccessibilityUtils.lightHaptic();
            onPressed?.call();
          };

    final child = isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: type == AccessibleButtonType.filled
                  ? Colors.white
                  : theme.colorScheme.primary,
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 24),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  softWrap: true,
                ),
              ),
            ],
          );

    switch (type) {
      case AccessibleButtonType.filled:
        return ElevatedButton(
          onPressed: effectiveOnPressed,
          onLongPress: onLongPress,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
          ),
          child: child,
        );
      case AccessibleButtonType.outlined:
        return OutlinedButton(
          onPressed: effectiveOnPressed,
          onLongPress: onLongPress,
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor,
            side: backgroundColor != null
                ? BorderSide(color: backgroundColor!, width: 2)
                : null,
          ),
          child: child,
        );
      case AccessibleButtonType.text:
        return TextButton(
          onPressed: effectiveOnPressed,
          onLongPress: onLongPress,
          style: TextButton.styleFrom(
            foregroundColor: foregroundColor,
          ),
          child: child,
        );
    }
  }
}

/// Buton tipleri
enum AccessibleButtonType { filled, outlined, text }
