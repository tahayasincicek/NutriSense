// =============================================================================
// lib/features/settings/screens/settings_screen.dart
// NutriSense — Ayarlar Ekranı
//
// Erişilebilirlik tercihleri, TTS hızı, tema, bildirim ayarları.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/widgets/accessible_text.dart';
import '../../auth/state/auth_controller.dart';

/// Ayarlar ekranı — erişilebilirlik ve uygulama tercihleri
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Tercih durumları (gerçek uygulamada SharedPreferences/Provider'dan gelecek)
  bool _isDarkMode = false;
  bool _highContrast = false;
  bool _hapticFeedback = true;
  double _ttsSpeed = 0.5;
  String _fontSize = 'large';
  bool _emailNotifications = true;
  bool _smsNotifications = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityUtils.announce(
        'Ayarlar ekranı. Erişilebilirlik, bildirim ve hesap ayarlarını düzenleyebilirsiniz.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ═══════════════════════════════════════════
          // ERİŞİLEBİLİRLİK AYARLARI
          // ═══════════════════════════════════════════
          _buildSectionHeader(context, 'Erişilebilirlik'),

          // Karanlık Mod
          _buildSwitchTile(
            title: 'Karanlık Mod',
            subtitle: 'Göz yorgunluğunu azaltır',
            semanticLabel:
                'Karanlık mod, şu an ${_isDarkMode ? "açık" : "kapalı"}',
            icon: Icons.dark_mode,
            value: _isDarkMode,
            onChanged: (value) {
              setState(() => _isDarkMode = value);
              AccessibilityUtils.announce(
                'Karanlık mod ${value ? "açıldı" : "kapatıldı"}',
              );
            },
          ),

          // Yüksek Kontrast
          _buildSwitchTile(
            title: 'Yüksek Kontrast',
            subtitle: 'Metinlerin okunurluğunu artırır',
            semanticLabel:
                'Yüksek kontrast modu, şu an ${_highContrast ? "açık" : "kapalı"}',
            icon: Icons.contrast,
            value: _highContrast,
            onChanged: (value) {
              setState(() => _highContrast = value);
              AccessibilityUtils.announce(
                'Yüksek kontrast ${value ? "açıldı" : "kapatıldı"}',
              );
            },
          ),

          // Haptic Feedback
          _buildSwitchTile(
            title: 'Titreşim Geri Bildirimi',
            subtitle: 'İşlemlerde titreşim ile bilgilendirir',
            semanticLabel:
                'Haptic geri bildirim, şu an ${_hapticFeedback ? "açık" : "kapalı"}',
            icon: Icons.vibration,
            value: _hapticFeedback,
            onChanged: (value) {
              setState(() => _hapticFeedback = value);
              AccessibilityUtils.announce(
                'Titreşim geri bildirimi ${value ? "açıldı" : "kapatıldı"}',
              );
            },
          ),

          // Font Boyutu
          Semantics(
            label: 'Yazı boyutu ayarı, şu an $_fontSize',
            child: ListTile(
              leading: const Icon(Icons.text_fields, size: 28),
              title: Text('Yazı Boyutu', style: theme.textTheme.titleSmall),
              subtitle:
                  Text(_fontSizeLabel(), style: theme.textTheme.bodySmall),
              trailing: DropdownButton<String>(
                value: _fontSize,
                items: const [
                  DropdownMenuItem(value: 'medium', child: Text('Orta')),
                  DropdownMenuItem(value: 'large', child: Text('Büyük')),
                  DropdownMenuItem(
                      value: 'extra_large', child: Text('Çok Büyük')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _fontSize = value);
                    AccessibilityUtils.announce(
                      'Yazı boyutu ${_fontSizeLabel()} olarak ayarlandı',
                    );
                  }
                },
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          ),

          const Divider(),

          // ═══════════════════════════════════════════
          // SES AYARLARI
          // ═══════════════════════════════════════════
          _buildSectionHeader(context, 'Ses Ayarları'),

          // TTS Hızı
          Semantics(
            label:
                'Konuşma hızı ayarı, şu an ${(_ttsSpeed * 100).toStringAsFixed(0)} yüzde',
            slider: true,
            child: ListTile(
              leading: const Icon(Icons.speed, size: 28),
              title: Text('Konuşma Hızı', style: theme.textTheme.titleSmall),
              subtitle: Slider(
                value: _ttsSpeed,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: '${(_ttsSpeed * 100).toStringAsFixed(0)}%',
                onChanged: (value) {
                  setState(() => _ttsSpeed = value);
                },
                onChangeEnd: (value) {
                  AccessibilityUtils.announce(
                    'Konuşma hızı ${(value * 100).toStringAsFixed(0)} yüzde olarak ayarlandı',
                  );
                },
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          ),

          const Divider(),

          // ═══════════════════════════════════════════
          // BİLDİRİM AYARLARI
          // ═══════════════════════════════════════════
          _buildSectionHeader(context, 'Bildirimler'),

          _buildSwitchTile(
            title: 'E-posta Bildirimleri',
            subtitle: 'Günlük özetler e-posta ile gönderilir',
            semanticLabel:
                'E-posta bildirimleri, şu an ${_emailNotifications ? "açık" : "kapalı"}',
            icon: Icons.email,
            value: _emailNotifications,
            onChanged: (value) {
              setState(() => _emailNotifications = value);
              AccessibilityUtils.announce(
                'E-posta bildirimleri ${value ? "açıldı" : "kapatıldı"}',
              );
            },
          ),

          _buildSwitchTile(
            title: 'SMS Bildirimleri',
            subtitle: 'Kritik uyarılar SMS ile gönderilir',
            semanticLabel:
                'SMS bildirimleri, şu an ${_smsNotifications ? "açık" : "kapalı"}',
            icon: Icons.sms,
            value: _smsNotifications,
            onChanged: (value) {
              setState(() => _smsNotifications = value);
              AccessibilityUtils.announce(
                'SMS bildirimleri ${value ? "açıldı" : "kapatıldı"}',
              );
            },
          ),

          const Divider(),

          // ═══════════════════════════════════════════
          // HESAP
          // ═══════════════════════════════════════════
          _buildSectionHeader(context, 'Hesap'),

          Semantics(
            button: true,
            label: 'Çıkış yap butonu',
            child: ListTile(
              leading:
                  Icon(Icons.logout, size: 28, color: theme.colorScheme.error),
              title: Text(
                'Çıkış Yap',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              onTap: _confirmLogout,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          ),

          Semantics(
            button: true,
            label: 'Hesabımı ve verilerimi kalıcı olarak sil',
            child: ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                size: 28,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Hesabı ve Verileri Sil',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              subtitle: const Text('Bu işlem geri alınamaz'),
              onTap: _showDeleteAccountDialog,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          ),

          const SizedBox(height: 24),

          // Uygulama versiyonu
          Center(
            child: AccessibleText(
              'NutriSense v1.0.0',
              style: theme.textTheme.bodySmall,
              semanticLabel: 'Uygulama sürümü 1.0.0',
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Bu cihazdaki güvenli oturum sonlandırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    AccessibilityUtils.announce('Çıkış yapılıyor');
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _showDeleteAccountDialog() async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    String? error;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Hesabı Kalıcı Olarak Sil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hesabınız ve beslenme kayıtlarınız silinir. Onaylamak için '
                  'şifrenizi ve HESABIMI SIL ifadesini girin.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Şifre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmation,
                  decoration: const InputDecoration(
                    labelText: 'HESABIMI SIL',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                if (confirmation.text != 'HESABIMI SIL' ||
                    password.text.isEmpty) {
                  setDialogState(() =>
                      error = 'Şifre ve onay ifadesi eksiksiz girilmelidir.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Kalıcı Olarak Sil'),
            ),
          ],
        ),
      ),
    );
    if (approved == true && mounted) {
      final result = await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(password.text);
      if (result != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result)));
        AccessibilityUtils.announceError(result);
      }
    }
    password.dispose();
    confirmation.dispose();
  }

  // ── Yardımcı Widgetlar ──

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: AccessibleText(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
        isHeader: true,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required String semanticLabel,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticLabel,
      toggled: value,
      child: SwitchListTile(
        secondary: Icon(icon, size: 28),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  String _fontSizeLabel() {
    switch (_fontSize) {
      case 'medium':
        return 'Orta';
      case 'large':
        return 'Büyük';
      case 'extra_large':
        return 'Çok Büyük';
      default:
        return 'Büyük';
    }
  }
}
