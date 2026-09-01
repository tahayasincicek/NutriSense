import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Giriş ve kayıt arasında geçiş yapan segment denetimi.
///
/// Diyetisyen erişim ekranındaki denetimin aynısıdır; hasta tarafında da aynı
/// görünümü kullanabilmek için paylaşılan bir bileşene taşındı. Seçili segment
/// bulunduğun ekranı gösterir, diğerine dokunmak o ekrana götürür.
class AuthModeSwitch extends StatelessWidget {
  const AuthModeSwitch({
    super.key,
    required this.registering,
    required this.onChanged,
    this.enabled = true,
    this.loginSemanticLabel,
    this.registerSemanticLabel,
  });

  /// true ise "Hesap Aç" segmenti seçilidir.
  final bool registering;

  /// Kullanıcı diğer segmente dokunduğunda çağrılır.
  final ValueChanged<bool> onChanged;

  final bool enabled;

  /// Ekran okuyucunun segmentler için okuyacağı açıklamalar. Verilmezse
  /// mod değiştirme ifadeleri kullanılır.
  final String? loginSemanticLabel;
  final String? registerSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: registering ? 'Kayıt modu seçili' : 'Giriş modu seçili',
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Giriş Yap',
                semanticLabel: loginSemanticLabel ?? 'Giriş moduna geç',
                icon: Icons.login_rounded,
                selected: !registering,
                enabled: enabled,
                onTap: () => onChanged(false),
              ),
            ),
            Expanded(
              child: _ModeButton(
                label: 'Hesap Aç',
                semanticLabel: registerSemanticLabel ?? 'Kayıt moduna geç',
                icon: Icons.person_add_alt_1_rounded,
                selected: registering,
                enabled: enabled,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant.withValues(
            alpha: enabled ? 1 : 0.45,
          );
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
