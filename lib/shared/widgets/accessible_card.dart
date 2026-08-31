// =============================================================================
// lib/shared/widgets/accessible_card.dart
// NutriSense — Erişilebilir Kart Widget'ı
//
// Besin bilgisi, kalori kaydı gibi verileri semantik etiketli, büyük
// dokunma alanlı kartlar içinde gösterir.
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/accessibility_utils.dart';

/// Erişilebilir kart — besin kartları, geçmiş kayıtları vb. için kullanılır.
///
/// ```dart
/// AccessibleCard(
///   semanticLabel: 'Elma, 78 kalori, öğle yemeği',
///   title: 'Elma',
///   subtitle: '78 kcal • 150g',
///   leading: Icon(Icons.apple),
///   onTap: () => showDetail(),
/// )
/// ```
class AccessibleCard extends StatelessWidget {
  final String semanticLabel;
  final String? semanticHint;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget? leading;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool enableHaptic;

  const AccessibleCard({
    super.key,
    required this.semanticLabel,
    this.semanticHint,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.trailingWidget,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.backgroundColor,
    this.enableHaptic = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: semanticLabel,
      hint: semanticHint ??
          (onTap != null ? 'Detayları görmek için çift dokunun' : null),
      button: onTap != null,
      onTap: onTap != null
          ? () {
              if (enableHaptic) AccessibilityUtils.lightHaptic();
              onTap!();
            }
          : null,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorScheme.surface.withOpacity(0.55),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap != null
                    ? () {
                        if (enableHaptic) AccessibilityUtils.lightHaptic();
                        onTap!();
                      }
                    : null,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: Row(
              children: [
                // Sol ikon veya görsel
                if (leading != null) ...[
                  SizedBox(
                    width: A11yConstants.minTouchTarget,
                    height: A11yConstants.minTouchTarget,
                    child: Center(child: leading!),
                  ),
                  const SizedBox(width: 16),
                ],

                // Başlık ve alt başlık
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Başlık — ExcludeSemantics çünkü kart seviyesinde
                      // label zaten okunuyor
                      ExcludeSemantics(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        ExcludeSemantics(
                          child: Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Sağ taraf (kalori bilgisi, ok ikonu vb.)
                if (trailing != null || trailingWidget != null) ...[
                  const SizedBox(width: 12),
                  trailingWidget ??
                      ExcludeSemantics(
                        child: Text(
                          trailing!,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                ],
              ],
            ),
          ), // Padding
        ), // InkWell
      ), // Material
    ), // BackdropFilter
  ), // ClipRRect
), // Container
); // Semantics
  }
}
