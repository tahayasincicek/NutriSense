// =============================================================================
// lib/shared/widgets/accessible_button.dart
// NutriSense — Erişilebilir Buton Widget'ı
//
// WCAG hedeflerini gözeten büyük dokunma alanı, semantik etiket, haptic feedback
// ve TTS geri bildirimi olan özel buton.
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
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

    final effectiveOnPressed = isLoading
        ? null
        : () {
            if (enableHaptic) AccessibilityUtils.lightHaptic();
            onPressed?.call();
          };

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticLabel ?? label,
      hint: semanticHint ?? 'Etkinleştirmek için çift dokunun',
      button: true,
      enabled: onPressed != null && !isLoading,
      onTap: effectiveOnPressed,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: fullWidth ? double.infinity : A11yConstants.minTouchTarget,
          minHeight: A11yConstants.minTouchTarget + 8,
        ),
        child: _buildButton(context, theme, effectiveOnPressed),
      ),
    );
  }

  Widget _buildButton(
      BuildContext context, ThemeData theme, VoidCallback? effectiveOnPressed) {
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
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            gradient: LinearGradient(
              colors: [
                backgroundColor ?? theme.colorScheme.primary,
                (backgroundColor ?? theme.colorScheme.primary)
                    .withBlue(50)
                    .withGreen(180),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (backgroundColor ?? theme.colorScheme.primary)
                    .withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: effectiveOnPressed,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              child: DefaultTextStyle(
                style: theme.textTheme.labelLarge!.copyWith(
                  color: foregroundColor ?? theme.colorScheme.onPrimary,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: foregroundColor ?? theme.colorScheme.onPrimary,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 16),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      case AccessibleButtonType.outlined:
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            border: Border.all(
              color: foregroundColor?.withValues(alpha: 0.5) ??
                  theme.colorScheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (foregroundColor ?? theme.colorScheme.primary)
                    .withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: effectiveOnPressed,
                  onLongPress: onLongPress,
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                  child: DefaultTextStyle(
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: foregroundColor ?? theme.colorScheme.primary,
                    ),
                    child: IconTheme(
                      data: IconThemeData(
                        color: foregroundColor ?? theme.colorScheme.primary,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 16),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
