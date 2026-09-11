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
import '../../auth/screens/privacy_consent_screen.dart';
import '../../../shared/services/api_service.dart';
import '../../dietitian/screens/dietitian_dashboard_screen.dart';
import '../../food_scan/state/on_device_model_preference.dart';
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
  /// Onay sorusunu seslendirir ve hemen ardından yeniden dinlemeye geçer.
  Future<void> _confirmLogoutByVoice() async {
    await _accessibility.speak(
      'Çıkışı onaylamak için evet deyin.',
      priority: TtsPriority.high,
    );
    if (!mounted) return;
    await _voiceCommand();
  }

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
          setState(() => _voiceStatus = 'Çıkışı onaylamak için evet deyin.');
          // Onay için mikrofon kendiliğinden yeniden açılır.
          unawaited(_confirmLogoutByVoice());
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

  /// Hesabın doğrulama durumunu gösterir.
  ///
  /// Rapor teslimatı doğrulanmış e-postaya bağlıdır; kullanıcı bunu
  /// göremediği için rapor gelmediğinde sebebini anlayamıyordu.
  Future<void> _showDietitianStatus() async {
    final dashboard =
        await ref.read(apiServiceProvider).getDietitianDashboard();
    if (!mounted) return;
    final data = dashboard.data;
    final message = data == null
        ? 'Hesap bilgisi alınamadı. Bağlantınızı kontrol edin.'
        : 'E-posta doğrulaması: '
            '${data.emailVerified ? "tamamlandı" : "bekliyor"}. '
            'Aktif danışan: ${data.activePatients}. '
            'Bekleyen eşleşme: ${data.pendingAssignments}.';
    _accessibility.speak(message, priority: TtsPriority.high);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hesap Durumu'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Diyetisyenin uzman profilini düzenler.
  ///
  /// Aynı diyalog panelde de kullanılır; ayarlardan da erişilebilmesi,
  /// kullanıcının profilini bulmak için panele dönmesini gereksiz kılar.
  Future<void> _openDietitianProfile() async {
    final api = ref.read(apiServiceProvider);
    final dashboard = await api.getDietitianDashboard();
    if (!mounted) return;
    final data = dashboard.data;
    if (data == null) {
      _accessibility.speak(
        'Profil bilgisi alınamadı. Bağlantınızı kontrol edin.',
        priority: TtsPriority.high,
      );
      return;
    }

    final entry = await showDialog<DietitianProfileEntry>(
      context: context,
      builder: (_) => DietitianProfileDialog(
        initialName: data.fullName,
        initialSpecialization: data.specialization,
      ),
    );
    if (entry == null || !mounted) return;
    if (entry.fullName.length < 2 || entry.specialization.length < 2) {
      _accessibility.speak(
        'Ad ve uzmanlık alanı en az iki karakter olmalıdır.',
        priority: TtsPriority.high,
      );
      return;
    }
    final result = await api.updateDietitianProfile(
      fullName: entry.fullName,
      specialization: entry.specialization,
      // Boş bırakıldıysa mevcut numara korunur; gönderilmez.
      phone: entry.phone.isEmpty ? null : entry.phone,
    );
    if (!mounted) return;
    _accessibility.speak(
      result.isSuccess
          ? 'Uzman profiliniz güncellendi.'
          : result.errorMessage ?? 'Profil güncellenemedi.',
      priority: TtsPriority.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    // Diyetisyen portalı hiç seslendirme yapmaz ve diyetisyen bir araştırma
    // katılımcısı değildir; hasta ayarlarını ona göstermek kafa karıştırır.
    final isDietitian = user?.accountType == 'dietitian';
    final profileName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Kullanıcı';

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
          _buildProfileHeader(profileName),
          const SizedBox(height: 32),

          _buildSectionTitle(isDietitian ? 'Görünüm' : 'Erişilebilirlik'),
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
            if (!isDietitian)
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

          if (isDietitian) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Diyetisyen'),
            _buildSettingCard([
              _buildActionTile(
                key: const Key('settings_dietitian_profile'),
                title: 'Uzman Profilim',
                icon: Icons.badge_rounded,
                color: AppTheme.primaryColor,
                onTap: _openDietitianProfile,
              ),
              // Rapor teslimatı doğrulanmış e-postaya bağlıdır; durumu
              // görmeden neden rapor gelmediği anlaşılamıyordu.
              _buildActionTile(
                key: const Key('settings_dietitian_status'),
                title: 'Hesap Durumu',
                icon: Icons.verified_rounded,
                color: AppTheme.primaryColor,
                onTap: _showDietitianStatus,
              ),
            ]),
          ],

          // Aşağıdaki bölümler yalnız hasta hesabı içindir: besin tanıma,
          // kalori hedefi, tanıtım ve araştırma araçları diyetisyeni
          // ilgilendirmez.
          if (!isDietitian) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Besin Tanıma'),
            _buildSettingCard([
              _buildSwitchTile(
                key: const Key('settings_on_device_model'),
                title: 'Cihaz Üstü Model',
                subtitle: 'İnternetsiz tanır; kaloriyi siz onaylarsınız',
                icon: Icons.memory_rounded,
                value: ref.watch(onDeviceModelProvider),
                onChanged: (v) {
                  ref.read(onDeviceModelProvider.notifier).setEnabled(v);
                  _accessibility.speak(
                    v
                        ? 'Cihaz üstü model açıldı. Tarama internete gitmez, '
                            'yalnız yemek adı önerilir.'
                        : 'Cihaz üstü model kapatıldı. Tarama sunucuda yapılır.',
                    priority: TtsPriority.high,
                  );
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
                key: const Key('settings_open_privacy'),
                title: 'Kişisel Verilerim ve İzinler',
                icon: Icons.shield_outlined,
                color: AppTheme.primaryColor,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyConsentScreen(),
                  ),
                ),
              ),
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
                  MaterialPageRoute(
                      builder: (_) => const UsabilityTestScreen()),
                ),
              ),
            ]),
          ],

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
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String profileName) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Semantics(
        container: true,
        header: true,
        excludeSemantics: true,
        label: '$profileName profili.',
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 35),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(profileName, style: theme.textTheme.titleLarge),
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
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
      {Key? key,
      required String title,
      required String subtitle,
      required IconData icon,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    // SwitchListTile kullanılır: başlık ile anahtarı tek bir semantik düğümde
    // birleştirir. Ayrı bir `trailing: Switch` bırakılsaydı anahtar adsız
    // kalır ve ekran okuyucu yalnız "düğme" derdi.
    // Sarmalayıcı adı, açıklamayı ve açık/kapalı durumunu taşır; dokunma
    // eylemini de kendisi sunar. İç anahtarın semantiği kapatılır, aksi
    // hâlde ekran okuyucu adsız ikinci bir düğüme odaklanıp yalnız "düğme"
    // der ve kullanıcı neyi açtığını bilmez.
    return Semantics(
      key: key,
      label: title,
      hint: subtitle,
      toggled: value,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: SwitchListTile(
        secondary: Icon(icon, color: AppTheme.primaryColor),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
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
      // Sarmalayıcı adı ve değeri taşır, eylemleri de kendisi sunar; iç
      // kaydırıcının semantiği kapatılır. Aksi hâlde ekran okuyucu adsız
      // ikinci bir düğüme odaklanıp yalnız "kaydırıcı" der.
      subtitle: Semantics(
        slider: true,
        label: title,
        value: 'yüzde $percent',
        // Artır/azalt eylemleri, ulaşılacak değerlerle birlikte bildirilmek
        // zorundadır; ekran okuyucu kullanıcıya sonucu önceden söyler.
        increasedValue:
            'yüzde ${((value + 0.1).clamp(0.1, 1.0) * 100).round()}',
        decreasedValue:
            'yüzde ${((value - 0.1).clamp(0.1, 1.0) * 100).round()}',
        excludeSemantics: true,
        onIncrease: () => onChanged((value + 0.1).clamp(0.1, 1.0)),
        onDecrease: () => onChanged((value - 0.1).clamp(0.1, 1.0)),
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
