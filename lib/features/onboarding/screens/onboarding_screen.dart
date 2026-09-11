// =============================================================================
// lib/features/onboarding/screens/onboarding_screen.dart
// NutriSense — İlk Kullanım Onboarding Ekranı
//
// 4 adımlı erişilebilir onboarding akışı:
//   1. Karşılama
//   2. Uygulamayı tanıtma (kamera, sesli komut)
//   3. İzinler (kamera, mikrofon)
//   4. Günlük kalori hedefi belirleme
//
// Her adımda TTS ile sesli anlatım.
// Sesli komutla navigasyon desteği.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../history/state/daily_goal_provider.dart';

/// Onboarding tamamlanma durumu kontrolü
const _kOnboardingCompleteKey = 'onboarding_complete';

Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingCompleteKey) ?? false;
}

Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingCompleteKey, true);
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onComplete,
    this.isReplay = false,
  });

  final VoidCallback onComplete;

  /// Ayarlar'dan tekrar dinlemek için açıldığında `true`.
  ///
  /// Tekrar izlemede kalori hedefi yeniden yazılmaz ve izinler yeniden
  /// istenmez; kullanıcı yalnızca anlatımı dinler.
  final bool isReplay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _cameraGranted = false;
  bool _micGranted = false;
  double _selectedGoal = 2000;

  late final AccessibilityService _accessibility;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.restaurant_rounded,
      title: 'NutriSense\'e Hoş Geldiniz',
      description:
          'Görme engelli bireyler için yapay zeka destekli beslenme takip uygulaması. '
          'Yiyeceklerinizi kamera ile tarayın, kalorilerini öğrenin.',
      ttsText:
          'NutriSense\'e hoş geldiniz! Bu uygulama görme engelli bireyler için '
          'yapay zeka destekli bir beslenme takip uygulamasıdır. '
          'Yiyeceklerinizi kamera ile tarayabilir ve kalorilerini sesli olarak öğrenebilirsiniz. '
          'Devam etmek için ekranın altındaki sonraki butonuna basın veya sonraki deyin.',
    ),
    _OnboardingPage(
      icon: Icons.mic_rounded,
      title: 'Sesli Kontrol',
      description: 'Uygulamayı tamamen sesli komutlarla kontrol edebilirsiniz. '
          '"Tara", "Geçmiş", "Gönder", "Yardım" gibi komutları kullanın.',
      ttsText: 'Bu uygulamayı tamamen sesli komutlarla kontrol edebilirsiniz. '
          'Tara diyerek kamerayı açabilir, Geçmiş diyerek yemek kayıtlarınızı dinleyebilir, '
          'Gönder diyerek diyetisyeninize rapor gönderebilir, '
          'Yardım diyerek tüm komutları öğrenebilirsiniz. '
          'Sonraki adıma geçmek için sonraki butonuna basın.',
    ),
    _OnboardingPage(
      icon: Icons.camera_alt_rounded,
      title: 'İzinler',
      description: 'Besin tanıma için kamera ve sesli komutlar için mikrofon '
          'izinlerini vermeniz gerekmektedir.',
      ttsText:
          'Uygulamanın çalışması için kamera ve mikrofon izinlerine ihtiyaç duyulmaktadır. '
          'Kamera izni besinleri tanımak için, mikrofon izni sesli komutlar için gereklidir. '
          'Lütfen izinleri verin ve sonraki adıma geçin.',
    ),
    _OnboardingPage(
      icon: Icons.track_changes_rounded,
      title: 'Kalori Hedefi',
      description: 'Günlük kalori hedefinizi belirleyin. '
          'Bu değeri daha sonra ayarlardan değiştirebilirsiniz.',
      ttsText: 'Son adım: Günlük kalori hedefinizi belirleyin. '
          'Varsayılan olarak 2000 kalori ayarlanmıştır. '
          'Kaydırıcı ile değiştirebilir veya olduğu gibi bırakabilirsiniz. '
          'Başlamak için tamamla butonuna basın.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentPage();
    });
  }

  void _announceCurrentPage() {
    final page = _pages[_currentPage];
    _accessibility.speak(page.ttsText, priority: TtsPriority.high);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestPermissions() async {
    // Tekrar izlemede izin diyaloğu açmıyoruz: kullanıcı yalnızca anlatımı
    // dinlemek için girmiş olabilir, beklenmedik sistem diyaloğu şaşırtır.
    // Bunun yerine mevcut izin durumu okunup sesli bildirilir.
    final cameraStatus = widget.isReplay
        ? await Permission.camera.status
        : await Permission.camera.request();
    final micStatus = widget.isReplay
        ? await Permission.microphone.status
        : await Permission.microphone.request();
    if (!mounted) return;
    setState(() {
      _cameraGranted = cameraStatus.isGranted;
      _micGranted = micStatus.isGranted;
    });

    final messages = <String>[];
    if (_cameraGranted) {
      messages.add('Kamera izni verildi');
    } else {
      messages.add('Kamera izni reddedildi. Besin tarama çalışmayacaktır');
    }
    if (_micGranted) {
      messages.add('Mikrofon izni verildi');
    } else {
      messages.add('Mikrofon izni reddedildi. Sesli komutlar çalışmayacaktır');
    }
    _accessibility.speak(messages.join('. '), priority: TtsPriority.high);
  }

  Future<void> _completeOnboarding() async {
    // Tekrar izlemede mevcut hedefi ve izinleri değiştirmiyoruz; kullanıcı
    // yalnızca anlatımı dinlemek için açmış olabilir.
    if (!widget.isReplay) {
      await ref
          .read(dailyGoalControllerProvider.notifier)
          .setGoal(_selectedGoal);
      await markOnboardingComplete();
    }

    _accessibility.speak(
      widget.isReplay
          ? 'Tanıtım tamamlandı. Ayarlara dönülüyor.'
          : 'Kurulum tamamlandı! NutriSense kullanıma hazır. '
              'Besin eklemek için besin ekle deyip adını söyleyebilirsiniz.',
      priority: TtsPriority.high,
    );
    await AccessibilityUtils.heavyHaptic();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Üst kısım — adım göstergesi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Semantics(
                label: 'Adım ${_currentPage + 1} / ${_pages.length}',
                child: Row(
                  children: List.generate(_pages.length, (index) {
                    final isActive = index <= _currentPage;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Sayfa içeriği
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _announceCurrentPage();
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  if (index == 2) return _buildPermissionsPage(theme);
                  if (index == 3) return _buildGoalPage(theme);
                  return _buildInfoPage(theme, _pages[index]);
                },
              ),
            ),

            // Alt kısım — navigasyon butonları
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: AccessibleButton(
                        label: 'Önceki',
                        semanticLabel: 'Önceki adıma geri dön',
                        icon: Icons.arrow_back_rounded,
                        type: AccessibleButtonType.outlined,
                        onPressed: _previousPage,
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: _currentPage == 0 ? 1 : 1,
                    child: AccessibleButton(
                      label: _currentPage == _pages.length - 1
                          ? 'Tamamla'
                          : 'Sonraki',
                      semanticLabel: _currentPage == _pages.length - 1
                          ? 'Kurulumu tamamla ve uygulamaya başla'
                          : 'Sonraki adıma geç',
                      icon: _currentPage == _pages.length - 1
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _nextPage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPage(ThemeData theme, _OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(page.icon, size: 56, color: Colors.white),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsPage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.security_rounded,
                size: 56, color: Colors.white),
          ),
          const SizedBox(height: 40),
          Text(
            'İzinler',
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Besin tanıma için kamera ve sesli komutlar için mikrofon '
            'izinlerini vermeniz gerekmektedir.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _PermissionRow(
            icon: Icons.camera_alt,
            label: 'Kamera',
            granted: _cameraGranted,
          ),
          const SizedBox(height: 12),
          _PermissionRow(
            icon: Icons.mic,
            label: 'Mikrofon',
            granted: _micGranted,
          ),
          const SizedBox(height: 24),
          AccessibleButton(
            key: const Key('onboarding_permissions'),
            label: widget.isReplay ? 'İzin Durumunu Dinle' : 'İzinleri Ver',
            semanticLabel: widget.isReplay
                ? 'Kamera ve mikrofon izinlerinin durumunu dinlemek için basın'
                : 'Kamera ve mikrofon izinlerini iste',
            icon: Icons.verified_user_outlined,
            onPressed: _requestPermissions,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalPage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.track_changes_rounded,
                size: 56, color: Colors.white),
          ),
          const SizedBox(height: 40),
          Text(
            'Günlük Kalori Hedefi',
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Semantics(
            label:
                'Günlük kalori hedefi: ${_selectedGoal.toStringAsFixed(0)} kalori',
            child: Text(
              '${_selectedGoal.toStringAsFixed(0)} kcal',
              style: theme.textTheme.displayMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            label: 'Kalori hedefi kaydırıcısı. '
                'Sola kaydırarak azaltın, sağa kaydırarak artırın. '
                'Şu anki değer: ${_selectedGoal.toStringAsFixed(0)} kalori.',
            slider: true,
            child: Slider(
              value: _selectedGoal,
              min: 1000,
              max: 4000,
              divisions: 30,
              label: '${_selectedGoal.toStringAsFixed(0)} kcal',
              onChanged: (value) {
                setState(() => _selectedGoal = value);
              },
              onChangeEnd: (value) {
                _accessibility.speak(
                  '${value.toStringAsFixed(0)} kalori seçildi.',
                  priority: TtsPriority.normal,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu değeri daha sonra ayarlardan değiştirebilirsiniz.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.ttsText,
  });

  final IconData icon;
  final String title;
  final String description;
  final String ttsText;
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.label,
    required this.granted,
  });

  final IconData icon;
  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label izni: ${granted ? "verildi" : "henüz verilmedi"}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: granted
              ? AppTheme.successColor.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: granted
                    ? AppTheme.successColor
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
            Icon(
              granted ? Icons.check_circle : Icons.circle_outlined,
              color: granted
                  ? AppTheme.successColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
