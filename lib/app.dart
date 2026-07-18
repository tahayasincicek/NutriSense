// =============================================================================
// lib/app.dart
// NutriSense — Ana Uygulama Scaffold'u ve Navigasyon
//
// Görme engelliler için optimize edilmiş BottomNavigationBar.
// Her sekme geçişinde:
//   - TTS ile sesli sayfa açıklaması
//   - Haptic feedback (titreşim)
//   - Semantik etiketler (TalkBack/VoiceOver)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/utils/accessibility_utils.dart';
import 'shared/services/accessibility_service.dart';
import 'shared/services/voice_command_service.dart';
import 'features/food_scan/screens/food_scan_screen.dart';
import 'features/history/screens/food_history_screen.dart';
import 'features/dietitian/screens/dietitian_screen.dart';
import 'features/settings/screens/settings_screen.dart';

/// Aktif sekme indeksini tutan Riverpod provider
final currentTabProvider = StateProvider<int>((ref) => 0);

/// Ana uygulama scaffold'u — BottomNavigationBar ile sekme navigasyonu
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  ListeningState _listeningState = ListeningState.idle;
  String? _voiceStatus;
  late final VoiceCommandService _voiceCmdService;
  // Sekmeler — lazy olarak oluşturulur (IndexedStack sayesinde state korunur)
  // Sekme bilgileri
  static const List<_TabInfo> _tabs = [
    _TabInfo(
      icon: Icons.camera_alt_outlined,
      activeIcon: Icons.camera_alt,
      label: 'Tara',
      semanticLabel: 'Besin tarama sekmesi. Kamerayı kullanarak besin tanıyın.',
      ttsAnnouncement:
          'Besin tarama sekmesi açıldı. Kamerayı besine tutarak taramaya başlayabilirsiniz.',
    ),
    _TabInfo(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      label: 'Geçmiş',
      semanticLabel:
          'Yemek geçmişi sekmesi. Günlük yemek kayıtlarınızı görüntüleyin.',
      ttsAnnouncement:
          'Yemek geçmişi sekmesi açıldı. Bugünkü yemek kayıtlarınızı görebilirsiniz.',
    ),
    _TabInfo(
      icon: Icons.medical_services_outlined,
      activeIcon: Icons.medical_services,
      label: 'Diyetisyen',
      semanticLabel:
          'Diyetisyen sekmesi. Diyetisyeninizle iletişim kurun ve rapor gönderin.',
      ttsAnnouncement:
          'Diyetisyen sekmesi açıldı. Rapor gönderebilir ve diyetisyen notlarını görebilirsiniz.',
    ),
    _TabInfo(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Ayarlar',
      semanticLabel:
          'Ayarlar sekmesi. Erişilebilirlik ve bildirim tercihlerinizi düzenleyin.',
      ttsAnnouncement:
          'Ayarlar sekmesi açıldı. Erişilebilirlik, bildirim ve hesap ayarlarını düzenleyebilirsiniz.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _voiceCmdService = ref.read(voiceCommandServiceProvider);
    // Uygulama açılışında hoş geldiniz mesajı
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityUtils.announce(
        'NutriSense uygulamasına hoş geldiniz. '
        'Alt menüden besin tarama, yemek geçmişi, diyetisyen ve '
        'ayarlar sekmelerine erişebilirsiniz. '
        'Sesli komut için mikrofon butonuna basın.',
      );

      // Sesli komut dinleyicisini ayarla
      _voiceCmdService.onCommandRecognized = _handleVoiceCommand;
      _voiceCmdService.onListeningStateChanged = (state) {
        if (!mounted) return;
        setState(() {
          _listeningState = state;
          _voiceStatus = switch (state) {
            ListeningState.listening =>
              'Sesli komut dinleniyor. Konuşmaya başlayın.',
            ListeningState.processing => 'Sesli komut işleniyor.',
            ListeningState.idle => null,
          };
        });
      };
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref
        .read(accessibilityServiceProvider)
        .setScreenReaderActive(MediaQuery.of(context).accessibleNavigation);
  }

  @override
  void dispose() {
    _voiceCmdService.onCommandRecognized = null;
    _voiceCmdService.onListeningStateChanged = null;
    _voiceCmdService.stopListening();
    super.dispose();
  }

  /// Sesli komut algılandığında çalıştırılacak işlem
  void _handleVoiceCommand(VoiceCommand command) {
    switch (command) {
      case VoiceCommand.scan:
        _onTabChanged(0);
        break;
      case VoiceCommand.history:
      case VoiceCommand.today:
        _onTabChanged(1);
        break;
      case VoiceCommand.send:
        _onTabChanged(2);
        break;
      case VoiceCommand.settings:
        _onTabChanged(3);
        break;
      case VoiceCommand.help:
        AccessibilityUtils.announce(
          'Tara, geçmiş, rapor gönder veya ayarlar diyerek sistemde gezinebilirsiniz.',
        );
        break;
      case VoiceCommand.cancel:
      case VoiceCommand.yes:
      case VoiceCommand.no:
        // Global navigasyon seviyesinde özel işlem yapılmaz
        break;
    }
  }

  /// Sekme değişikliğini yönetir — TTS + Haptic + State güncelleme
  void _onTabChanged(int index) {
    final currentIndex = ref.read(currentTabProvider);
    if (index == currentIndex) {
      return; // Aynı sekmeye tekrar basılmasını engelle
    }

    // Haptic feedback
    AccessibilityUtils.lightHaptic();

    // State güncelle
    ref.read(currentTabProvider.notifier).state = index;

    // Sesli duyuru — ekran okuyucu aktifse SemanticsService,
    // değilse TTS kullan
    final tab = _tabs[index];
    AccessibilityUtils.announcePageChange(tab.label);

    // TTS ile detaylı açıklama (ekran okuyucu kullanmayanlar için)
    final accessibility = ref.read(accessibilityServiceProvider);
    accessibility.speak(tab.ttsAnnouncement);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentTabProvider);
    final theme = Theme.of(context);
    final accessibility = ref.read(accessibilityServiceProvider);

    return Scaffold(
      // IndexedStack: tüm sekmelerin state'ini korur, her seferinde rebuild etmez
      body: Column(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: accessibility.ttsFailureListenable,
            builder: (context, failure, _) {
              if (failure == null) return const SizedBox.shrink();
              return Semantics(
                liveRegion: true,
                container: true,
                label: 'Sesli okuma kullanılamıyor. $failure',
                child: MaterialBanner(
                  key: const Key('tts_failure_banner'),
                  content: Text(failure),
                  leading: const Icon(Icons.volume_off_outlined),
                  actions: [
                    TextButton(
                      onPressed: () => _onTabChanged(3),
                      child: const Text('Ayarları Aç'),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: currentIndex,
                  children: [
                    const FoodScanScreen(),
                    FoodHistoryScreen(onScanRequested: () => _onTabChanged(0)),
                    const DietitianScreen(),
                    const SettingsScreen(),
                  ],
                ),
                if (_voiceStatus != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Semantics(
                      liveRegion: true,
                      label: _voiceStatus,
                      child: Material(
                        color: theme.colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _voiceStatus!,
                            key: const Key('global_voice_status'),
                            style: TextStyle(
                              color: theme.colorScheme.onInverseSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      // BottomNavigationBar — erişilebilir, büyük ikonlar, semantik etiketli
      bottomNavigationBar: Semantics(
        label: 'Ana navigasyon çubuğu, 4 sekme',
        child: Container(
          // Üst kenarlık — görsel ayrım
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.dividerTheme.color ?? Colors.grey,
                width: 1,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: _onTabChanged,
            items: _tabs.map((tab) {
              return BottomNavigationBarItem(
                icon: Semantics(
                  label: tab.semanticLabel,
                  child: _NavigationIcon(
                    icon: tab.icon,
                    selected: false,
                  ),
                ),
                activeIcon: Semantics(
                  label: '${tab.label} sekmesi, seçili',
                  child: _NavigationIcon(
                    icon: tab.activeIcon,
                    selected: true,
                  ),
                ),
                label: tab.label,
                tooltip: tab.semanticLabel,
              );
            }).toList(),
          ),
        ),
      ),

      // Floating Action Button — sesli komut kısayolu
      floatingActionButton: Semantics(
        label: _listeningState == ListeningState.listening
            ? 'Sesli komut dinleniyor. Durdurmak için dokunun.'
            : 'Sesli komut butonu. Mikrofona konuşarak komut verin.',
        hint: 'Çift dokunarak sesli komutu başlatın',
        button: true,
        child: FloatingActionButton(
          onPressed: _startVoiceCommand,
          heroTag: 'voice_command_fab',
          child: Icon(
            _listeningState == ListeningState.listening
                ? Icons.mic
                : Icons.mic_none,
            size: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// Sesli komut dinlemeyi başlatır
  void _startVoiceCommand() {
    _voiceCmdService.toggleListening();
  }
}

/// Sekme bilgileri veri sınıfı
class _TabInfo {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String semanticLabel;
  final String ttsAnnouncement;

  const _TabInfo({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.semanticLabel,
    required this.ttsAnnouncement,
  });
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 38,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            width: selected ? 32 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 7),
          Icon(icon),
        ],
      ),
    );
  }
}
