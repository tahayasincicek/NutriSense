// =============================================================================
// lib/features/settings/screens/settings_screen.dart
// NutriSense — Ayarlar Ekranı
//
// Erişilebilirlik tercihleri, TTS hızı, tema, bildirim ayarları.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/contextual_voice_command.dart';
import '../../../shared/services/stt_service.dart';
import '../../../shared/widgets/accessible_text.dart';
import '../../auth/state/auth_controller.dart';

/// Ayarlar ekranı — erişilebilirlik ve uygulama tercihleri
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _voiceParser = ContextualVoiceCommandParser();
  final _voiceConfirmation = VoiceConfirmationGate();
  late final AccessibilityService _accessibility;
  late final SttService _stt;
  bool _voiceListening = false;
  String? _voiceStatus;
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
    _accessibility = ref.read(accessibilityServiceProvider);
    _stt = ref.read(sttServiceProvider);
    _highContrast = _accessibility.highContrast;
    _hapticFeedback = _accessibility.vibrationEnabled;
    _ttsSpeed = _accessibility.speechRate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityUtils.announce(
        'Ayarlar ekranı. Erişilebilirlik, bildirim ve hesap ayarlarını düzenleyebilirsiniz.',
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accessibility
        .setScreenReaderActive(MediaQuery.of(context).accessibleNavigation);
  }

  @override
  void dispose() {
    if (_voiceListening) unawaited(_stt.cancelListening());
    _accessibility.finishSpeechInput();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        actions: [
          IconButton(
            key: const Key('settings_voice_action'),
            tooltip: _voiceListening
                ? 'Sesli komutu durdur'
                : 'Ayarlar sesli komutunu başlat',
            onPressed: _toggleVoiceInteraction,
            icon: Icon(_voiceListening ? Icons.mic : Icons.mic_none),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (_voiceStatus != null)
            Semantics(
              liveRegion: true,
              container: true,
              label: _voiceStatus,
              child: MaterialBanner(
                key: const Key('settings_voice_status'),
                content: Text(_voiceStatus!),
                actions: [
                  TextButton(
                    onPressed: _cancelVoiceInteraction,
                    child: const Text('İptal'),
                  ),
                ],
              ),
            ),
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
              unawaited(_accessibility.setHighContrast(value));
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
              unawaited(_accessibility.setVibrationEnabled(value));
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
                  unawaited(_accessibility.setSpeechRate(value));
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
    await _performLogout();
  }

  Future<void> _performLogout() async {
    AccessibilityUtils.announce('Çıkış yapılıyor');
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _toggleVoiceInteraction() async {
    if (_voiceListening) {
      await _cancelVoiceInteraction();
      return;
    }
    await _accessibility.prepareForSpeechInput();
    if (!mounted) return;
    setState(() {
      _voiceListening = true;
      _voiceStatus = _voiceConfirmation.isActive
          ? 'Çıkışı onaylamak için yalnız “evet”, vazgeçmek için “hayır” deyin.'
          : 'Ayarlar için dinleniyor. Çıkış yapmak için “çıkış yap” deyin.';
    });
    unawaited(_accessibility.lightHaptic());
    await _stt.startListening(
      listenFor: const Duration(seconds: 12),
      onResult: (result) {
        if (!mounted) return;
        if (!result.isFinal) {
          setState(() => _voiceStatus = result.text.trim().isEmpty
              ? 'Dinleniyor…'
              : 'Algılanan: ${result.text}. Komut henüz çalıştırılmadı.');
          return;
        }
        _accessibility.finishSpeechInput();
        setState(() => _voiceListening = false);
        unawaited(_handleVoiceIntent(result.text));
      },
      onError: (message) {
        _accessibility.finishSpeechInput();
        if (!mounted) return;
        setState(() {
          _voiceListening = false;
          _voiceStatus = '$message. Çıkış Yap düğmesini kullanabilirsiniz.';
        });
        unawaited(_accessibility.errorHaptic());
      },
      onListeningStopped: () {
        _accessibility.finishSpeechInput();
        if (mounted) setState(() => _voiceListening = false);
      },
    );
  }

  Future<void> _handleVoiceIntent(String transcript) async {
    final confirmationActive = _voiceConfirmation.isActive;
    final intent = _voiceParser.parse(
      transcript,
      context: confirmationActive
          ? VoiceInteractionContext.logoutConfirmation
          : VoiceInteractionContext.settings,
    );
    if (confirmationActive) {
      final resolved = _voiceConfirmation.resolve(intent);
      if (resolved == ContextualVoiceAction.logout) {
        if (mounted) setState(() => _voiceStatus = 'Çıkış onaylandı.');
        await _performLogout();
        return;
      }
      if (!mounted) return;
      setState(() => _voiceStatus = _voiceConfirmation.isActive
          ? 'Çıkış yapılmadı. Onay için yalnız tam olarak “evet” deyin.'
          : 'Çıkış iptal edildi.');
      return;
    }
    if (intent.action == ContextualVoiceAction.logout && intent.isExact) {
      _voiceConfirmation.request(ContextualVoiceAction.logout);
      setState(() => _voiceStatus =
          'Güvenli oturum kapatılacak. Mikrofon düğmesine tekrar basıp yalnız tam olarak “evet” deyin.');
      await _accessibility.speakWarning(
        'Çıkış yapmak için mikrofon düğmesine tekrar basıp evet deyin.',
      );
      return;
    }
    if (intent.action == ContextualVoiceAction.cancel) {
      await _cancelVoiceInteraction();
      return;
    }
    if (!mounted) return;
    setState(() => _voiceStatus =
        '${intent.rejectionReason ?? "Bu komut ayarlarda kullanılamaz."} Çıkış Yap düğmesini de kullanabilirsiniz.');
  }

  Future<void> _cancelVoiceInteraction() async {
    if (_voiceListening) await _stt.cancelListening();
    _accessibility.finishSpeechInput();
    _voiceConfirmation.clear();
    if (!mounted) return;
    setState(() {
      _voiceListening = false;
      _voiceStatus = null;
    });
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
