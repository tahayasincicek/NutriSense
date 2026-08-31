import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/contextual_voice_command.dart';
import '../../../shared/services/stt_service.dart';
import '../../auth/state/auth_controller.dart';
import '../../history/state/daily_goal_provider.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../survey/screens/survey_screen.dart';
import '../../survey/screens/usability_test_screen.dart';
import '../../../shared/widgets/accessible_number_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _voiceParser = ContextualVoiceCommandParser();

  late final AccessibilityService _accessibility;
  late final SttService _stt;
  double _ttsSpeed = 0.5;

  /// Sesli çıkış iki adımlıdır; ilk komuttan sonra onay bekleriz.
  bool _pendingVoiceLogout = false;
  String? _voiceStatus;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _stt = ref.read(sttServiceProvider);
    _ttsSpeed = _accessibility.speechRate;
  }

  /// Sesli komutla oturum kapatma.
  ///
  /// Tek adımda çıkış yapmak, yanlış tanımada kullanıcıyı oturumundan eder;
  /// bu yüzden komut ve onay ayrı ayrı alınır.
  Future<void> _voiceCommand() async {
    final pending = _pendingVoiceLogout;
    await _stt.startListening(
      onResult: (result) {
        if (!mounted) return;
        if (!result.isFinal) {
          setState(() =>
              _voiceStatus = 'Komut henüz çalıştırılmadı; lütfen tamamlayın.');
          return;
        }
        final intent = _voiceParser.parse(
          result.text,
          context: pending
              ? VoiceInteractionContext.logoutConfirmation
              : VoiceInteractionContext.settings,
        );
        if (pending) {
          _pendingVoiceLogout = false;
          if (intent.action == ContextualVoiceAction.yes) {
            setState(() => _voiceStatus = null);
            ref.read(authControllerProvider.notifier).logout();
            _accessibility.speak('Oturum kapatıldı.',
                priority: TtsPriority.high);
            return;
          }
          setState(() => _voiceStatus = 'Çıkış iptal edildi.');
          return;
        }
        if (intent.action == ContextualVoiceAction.logout) {
          _pendingVoiceLogout = true;
          setState(() => _voiceStatus =
              'Çıkışı onaylamak için: Mikrofon düğmesine tekrar basıp '
                  'evet deyin.');
          _accessibility.speak(_voiceStatus!, priority: TtsPriority.high);
          return;
        }
        setState(
            () => _voiceStatus = 'Komut henüz çalıştırılmadı; anlaşılamadı.');
      },
      onError: (_) {
        if (!mounted) return;
        setState(
            () => _voiceStatus = 'Komut henüz çalıştırılmadı; ses hatası.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // Bu ekran Navigator.push ile açılır; arkasında AppShell
      // boyaması yoktur, arka planı temadan almalıdır.
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('settings_voice_action'),
            icon: const Icon(Icons.mic_none_rounded),
            tooltip: 'Sesli komut',
            onPressed: _voiceCommand,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        children: [
          if (_voiceStatus != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _voiceStatus!,
                    style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
              ),
            ),
          _buildProfileHeader(),
          const SizedBox(height: 32),

          _buildSectionTitle('Erişilebilirlik'),
          _buildSettingCard([
            _buildSwitchTile(
              title: 'Karanlık Mod',
              subtitle: 'Daha az göz yorgunluğu',
              icon: Icons.dark_mode_rounded,
              value: ref
                  .watch(themeControllerProvider.notifier)
                  .isDark(MediaQuery.platformBrightnessOf(context)),
              onChanged: (v) {
                ref.read(themeControllerProvider.notifier).setDark(v);
                _accessibility.speak(
                  v ? 'Karanlık mod açıldı.' : 'Aydınlık mod açıldı.',
                  priority: TtsPriority.high,
                );
              },
            ),
            _buildSliderTile(
              title: 'Konuşma Hızı',
              icon: Icons.record_voice_over_rounded,
              value: _ttsSpeed,
              onChanged: (v) {
                setState(() => _ttsSpeed = v);
                _accessibility.setSpeechRate(v);
              },
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionTitle('Beslenme Hedefleri'),
          _buildSettingCard([
            _buildGoalSlider(),
          ]),

          const SizedBox(height: 24),
          _buildSectionTitle('Yardım'),
          _buildSettingCard([
            _buildActionTile(
              key: const Key('settings_replay_onboarding'),
              title: 'Tanıtımı Tekrar Dinle',
              icon: Icons.replay_rounded,
              color: AppTheme.primaryColor,
              onTap: _replayOnboarding,
            ),
          ]),

          const SizedBox(height: 24),
          // Araştırma araçları: TÜBİTAK metodolojisinde vaat edilen anket ve
          // kullanılabilirlik testi verilerini toplamak için kullanılır.
          _buildSectionTitle('Araştırma'),
          _buildSettingCard([
            _buildActionTile(
              key: const Key('settings_open_survey'),
              title: 'Anket',
              icon: Icons.assignment_outlined,
              color: AppTheme.primaryColor,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SurveyScreen()),
              ),
            ),
            _buildActionTile(
              key: const Key('settings_open_usability'),
              title: 'Kullanılabilirlik Testi',
              icon: Icons.science_outlined,
              color: AppTheme.primaryColor,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UsabilityTestScreen()),
              ),
            ),
          ]),

          const SizedBox(height: 24),
          _buildSectionTitle('Hesap Yönetimi'),
          _buildSettingCard([
            _buildActionTile(
              title: 'Oturumu Kapat',
              icon: Icons.logout_rounded,
              color: AppTheme.errorColor,
              onTap: _confirmLogout,
            ),
            _buildActionTile(
              title: 'Hesabı Sil',
              icon: Icons.delete_forever_rounded,
              color: AppTheme.errorColor,
              onTap: _confirmDeleteAccount,
            ),
          ]),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'NutriSense v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Semantics(
        container: true,
        header: true,
        excludeSemantics: true,
        label: 'Kullanıcı profili. Premium üye.',
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 35),
            ),
            const SizedBox(width: 16),
            // Büyük fontta metin sığmayınca taşıyordu; esnek hale getirildi.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Kullanıcı Profili', style: theme.textTheme.titleLarge),
                  Text('Premium Üye',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primaryDark)),
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
      {required String title,
      required String subtitle,
      required IconData icon,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
    );
  }

  Widget _buildSliderTile(
      {required String title,
      required IconData icon,
      required double value,
      required ValueChanged<double> onChanged}) {
    // Kaydırıcı tek yol olmamalı: yüzde değerini sesle de söyleyebilmeli.
    final percent = (value * 100).round();
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: Semantics(
        slider: true,
        label: title,
        value: 'yüzde $percent',
        child: Slider(
          key: const Key('tts_speed_slider'),
          value: value,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          label: 'yüzde $percent',
          onChanged: onChanged,
          onChangeEnd: (v) => _accessibility.speak(
            '$title yüzde ${(v * 100).round()}',
            priority: TtsPriority.high,
          ),
        ),
      ),
      trailing: IconButton(
        key: const Key('tts_speed_voice'),
        icon: const Icon(Icons.mic_none_rounded),
        tooltip: '$title değerini sesle söyle',
        onPressed: () async {
          final spoken = await showAccessibleNumberDialog(
            context: context,
            title: title,
            fieldLabel: title,
            suffix: '%',
            spokenUnit: 'yüzde',
            min: 10,
            max: 100,
            step: 10,
            initialValue: percent.toDouble(),
          );
          if (spoken != null) onChanged(spoken / 100);
        },
      ),
    );
  }

  Widget _buildGoalSlider() {
    return Consumer(builder: (context, ref, _) {
      final goal = ref.watch(dailyGoalControllerProvider);
      final calories = goal.goalCalories;
      return ListTile(
        leading: const Icon(Icons.bolt_rounded, color: AppTheme.primaryColor),
        title: const Text('Günlük Kalori Hedefi'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              slider: true,
              label: 'Günlük kalori hedefi',
              value: '${calories.toStringAsFixed(0)} kalori',
              child: Slider(
                key: const Key('calorie_goal_slider'),
                value: calories,
                min: 1200,
                max: 3500,
                divisions: 23,
                label: '${calories.toStringAsFixed(0)} kcal',
                onChanged: (v) =>
                    ref.read(dailyGoalControllerProvider.notifier).setGoal(v),
                onChangeEnd: (v) => _accessibility.speak(
                  'Günlük hedef ${v.toStringAsFixed(0)} kalori',
                  priority: TtsPriority.high,
                ),
              ),
            ),
            Text('${calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ],
        ),
        trailing: IconButton(
          key: const Key('calorie_goal_voice'),
          icon: const Icon(Icons.mic_none_rounded),
          tooltip: 'Kalori hedefini sesle söyle',
          onPressed: () async {
            final spoken = await showAccessibleNumberDialog(
              context: context,
              title: 'Günlük Kalori Hedefi',
              fieldLabel: 'Kalori hedefi',
              suffix: 'kcal',
              spokenUnit: 'kalori',
              min: 1200,
              max: 3500,
              step: 50,
              initialValue: calories,
            );
            if (spoken != null) {
              ref.read(dailyGoalControllerProvider.notifier).setGoal(spoken);
            }
          },
        ),
      );
    });
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Key? key,
  }) {
    return ListTile(
      key: key,
      leading: Icon(icon, color: color),
      title: Text(title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  /// Sesli tanıtımı yeniden oynatır.
  ///
  /// Tekrar izlemede kalori hedefi ve izinler değiştirilmez; kullanıcı
  /// uygulamanın nasıl kullanıldığını hatırlamak için açar.
  Future<void> _replayOnboarding() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OnboardingScreen(
          isReplay: true,
          onComplete: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Çıkış Yap')),
        ],
      ),
    );
    if (confirmed == true) ref.read(authControllerProvider.notifier).logout();
  }

  /// Hesap silme geri alınamaz; şifre doğrulaması istenir ve her adım
  /// sesli duyurulur.
  Future<void> _confirmDeleteAccount() async {
    _accessibility.speak(
      'Hesabı silme işlemi geri alınamaz. Onaylamak için şifreniz istenecek.',
      priority: TtsPriority.high,
    );
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || password.isEmpty || !mounted) return;

    final error =
        await ref.read(authControllerProvider.notifier).deleteAccount(password);
    if (!mounted) return;
    if (error != null) {
      _accessibility.speakError(error);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _accessibility.speak('Hesabınız silindi.', priority: TtsPriority.high);
  }
}

/// Hesap silme onayı: şifre girilmeden işlem yapılmaz.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hesabı Sil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Bu işlem geri alınamaz. Tüm beslenme kayıtlarınız silinir. '
            'Devam etmek için şifrenizi girin.',
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Şifre doğrulama alanı',
            textField: true,
            obscured: _obscure,
            child: TextField(
              key: const Key('delete_account_password'),
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Şifre',
                suffixIcon: IconButton(
                  icon:
                      Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('delete_account_confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Hesabı Sil'),
        ),
      ],
    );
  }
}
