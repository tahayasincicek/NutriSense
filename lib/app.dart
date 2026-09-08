import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/utils/accessibility_utils.dart';
import 'shared/services/accessibility_service.dart';
import 'shared/services/shake_detector.dart';
import 'shared/services/shake_preference.dart';
import 'shared/services/api_service.dart';
import 'shared/services/contextual_voice_command.dart';
import 'shared/services/stt_service.dart';
import 'features/history/state/history_controller.dart';
import 'shared/services/turkish_number_parser.dart';
import 'shared/services/voice_command_service.dart';
import 'shared/services/voice_help_service.dart';
import 'features/food_scan/screens/food_scan_screen.dart';
import 'features/history/screens/food_history_screen.dart';
import 'features/history/screens/food_shortcuts_screen.dart';
import 'features/discover/screens/discover_screen.dart';
import 'features/water_tracker/screens/water_tracker_screen.dart'; // Bu dosya ActivityTrackerScreen sınıfını barındırıyor
import 'features/dietitian/screens/dietitian_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/water_tracker/state/water_provider.dart';

final currentTabProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  static const _voiceParser = ContextualVoiceCommandParser();

  ListeningState _listeningState = ListeningState.idle;
  late final VoiceCommandService _voiceCmdService;
  late final ShakeDetector _shakeDetector;
  String? _voiceStatus;
  Timer? _statusTimer;

  static const List<_TabInfo> _tabs = [
    _TabInfo(
      icon: Icons.camera_alt_outlined,
      activeIcon: Icons.camera_alt_rounded,
      label: 'Tara',
      ttsAnnouncement: 'Besin tarama ekranı.',
    ),
    _TabInfo(
      icon: Icons.auto_graph_outlined,
      activeIcon: Icons.auto_graph_rounded,
      label: 'Aktivite',
      ttsAnnouncement: 'Aktivite ve su takibi ekranı.',
    ),
    _TabInfo(
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      label: 'Günlük',
      ttsAnnouncement: 'Beslenme günlüğü ekranı.',
    ),
    _TabInfo(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'Keşfet',
      ttsAnnouncement: 'Keşfet; tarifler ve ipuçları ekranı.',
    ),
    _TabInfo(
      icon: Icons.medical_services_outlined,
      activeIcon: Icons.medical_services_rounded,
      label: 'Diyetisyen',
      ttsAnnouncement: 'Diyetisyen paneli.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceCmdService = ref.read(voiceCommandServiceProvider);
    _shakeDetector = ShakeDetector();

    _voiceCmdService.onCommandRecognized = (result) {
      if (mounted) {
        setState(() {
          if (result.recognized && result.command != null) {
            _voiceStatus = 'Komut anlaşıldı: ${result.rawText}';
            if (result.command == VoiceCommand.scan) _onTabChanged(0);
            if (result.command == VoiceCommand.history) _onTabChanged(2);

            // "yardım" / "ne diyebilirim": bulunulan sekmeye göre kullanılabilir
            // komutları okur. Kullanıcı yolunu kaybettiğinde başvuracağı yol.
            if (result.command == VoiceCommand.help) {
              _announceHelp();
            }
            if (result.command == VoiceCommand.today) _onTabChanged(2);
            if (result.command == VoiceCommand.settings) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            }
            if (result.command == VoiceCommand.cancel) {
              ref
                  .read(accessibilityServiceProvider)
                  .speak('İptal edildi.', priority: TtsPriority.high);
            }

            // Yeni Sağlık Takibi Komutları
            if (result.command == VoiceCommand.addWater) {
              ref.read(activityProvider.notifier).addWater(200); // 200ml ekle
              _onTabChanged(1); // Aktivite sekmesini aç
            }
            if (result.command == VoiceCommand.setMood) {
              String mood = 'Normal';
              final text = result.rawText.toLowerCase();
              if (text.contains('mutlu')) mood = 'Mutlu';
              if (text.contains('üzgün')) mood = 'Üzgün';
              if (text.contains('yorgun')) mood = 'Yorgun';
              if (text.contains('enerjik')) mood = 'Enerjik';
              ref.read(activityProvider.notifier).setMood(mood);
              _onTabChanged(1);
              ref.read(accessibilityServiceProvider).speak(
                    '$mood hissediyorsunuz. Kaydedildi.',
                    priority: TtsPriority.high,
                  );
            }
            // "kilomu kaydet yetmiş dört buçuk" gibi sözcükle söylenen
            // sayıları da anlar; rakam söylemek zorunlu değil.
            if (result.command == VoiceCommand.logWeight) {
              _logMeasurement(
                rawText: result.rawText,
                min: 20,
                max: 400,
                unit: 'kilogram',
                prompt: 'Kilonuzu söyleyin. Örneğin yetmiş dört buçuk.',
                onValue: (value) =>
                    ref.read(activityProvider.notifier).updateWeight(value),
              );
            }
            if (result.command == VoiceCommand.logSleep) {
              _logMeasurement(
                rawText: result.rawText,
                min: 0,
                max: 24,
                unit: 'saat',
                prompt: 'Kaç saat uyudunuz? Örneğin yedi buçuk.',
                onValue: (value) =>
                    ref.read(activityProvider.notifier).setSleep(value),
              );
            }
            if (result.command == VoiceCommand.logFood) {
              _logFoodByVoice(result.rawText);
            }
            if ({
                  VoiceCommand.frequentMeals,
                  VoiceCommand.usualBreakfast,
                  VoiceCommand.undoFood
                }.contains(result.command) &&
                ModalRoute.of(context)?.isCurrent == true) {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FoodShortcutsScreen(
                        openUndo: result.command == VoiceCommand.undoFood,
                        breakfast:
                            result.command == VoiceCommand.usualBreakfast,
                      )));
            }
          } else {
            // Komut anlaşılmadığında kullanıcıyı çıkmazda bırakmamak için
            // yardıma yönlendiriyoruz.
            _voiceStatus = 'Anlaşılamadı: ${result.rawText}';
            ref.read(accessibilityServiceProvider).speak(
                  'Komut anlaşılamadı. Kullanabileceğiniz komutları dinlemek '
                  'için ne diyebilirim deyin.',
                  priority: TtsPriority.high,
                );
          }
        });

        _statusTimer?.cancel();
        _statusTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _voiceStatus = null);
        });
      }
    };

    _voiceCmdService.onListeningStateChanged = (state) {
      if (mounted) setState(() => _listeningState = state);
    };
  }

  /// Sallayarak sesli komut. Kullanıcı ekranda düğme aramadan komut verebilir;
  /// mikrofon sürekli açık kalmaz, yalnız sallama anında dinleme başlar.
  void _onShake() {
    if (!mounted || _voiceCmdService.isListening) return;
    ref.read(accessibilityServiceProvider).mediumHaptic();
    _voiceCmdService.startListening();
  }

  void _syncShakeDetector(bool enabled) {
    if (enabled && !_shakeDetector.isRunning) {
      _shakeDetector.start(_onShake);
    } else if (!enabled && _shakeDetector.isRunning) {
      unawaited(_shakeDetector.stop());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Arka planda sensör dinlemek pil tüketir ve kullanıcı ekranı görmezken
    // istemsiz komut başlatabilir.
    if (state == AppLifecycleState.resumed) {
      _syncShakeDetector(ref.read(shakeToListenProvider));
    } else {
      unawaited(_shakeDetector.stop());
    }
  }

  @override
  void dispose() {
    unawaited(_shakeDetector.stop());
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TalkBack/VoiceOver açıkken uygulamanın kendi TTS'i susmalı, yoksa iki
    // ses üst üste biner. Bunu kök kabuktan bildiriyoruz ki her ekranda
    // ayrı ayrı tekrarlanmasın; MediaQuery değişince otomatik güncellenir.
    ref
        .read(accessibilityServiceProvider)
        .setScreenReaderActive(MediaQuery.of(context).accessibleNavigation);
  }

  /// Besini yalnızca konuşarak kaydeder.
  ///
  /// Hiçbir düğme aranmaz, hiçbir ekrana gidilmez: komutta besin adı varsa
  /// ("köfte ekle") doğrudan arar; yoksa adı sorar. Bulunan besin porsiyonuyla
  /// birlikte okunur ve sesli onay istenir. Görme engelli kullanıcı için
  /// birincil kayıt yolu budur.
  Future<void> _logFoodByVoice(String rawText) async {
    final accessibility = ref.read(accessibilityServiceProvider);

    // Komut sözcüklerini ayıklayıp geriye besin adını bırak.
    var name = rawText.toLowerCase();
    for (final alias in VoiceCommand.logFood.aliases) {
      name = name.replaceAll(alias, ' ');
    }
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (name.length < 2) {
      accessibility.speak(
        'Hangi besini eklemek istiyorsunuz? Besin adını söyleyin.',
        priority: TtsPriority.high,
      );
      await ref.read(sttServiceProvider).startListening(
            onResult: (result) {
              if (!result.isFinal) return;
              final spoken = result.text.trim();
              if (spoken.length < 2) {
                accessibility.speakError('Besin adı anlaşılamadı.');
                return;
              }
              unawaited(_searchAndConfirmFood(spoken));
            },
            onError: (_) => accessibility.speakError(
              'Ses tanıma kullanılamıyor. Tara sekmesinden manuel '
              'besin ekleyebilirsiniz.',
            ),
          );
      return;
    }

    await _searchAndConfirmFood(name);
  }

  /// Besini arar, sonucu okur ve sesli onay aldıktan sonra kaydeder.
  Future<void> _searchAndConfirmFood(String query) async {
    final accessibility = ref.read(accessibilityServiceProvider);
    final api = ref.read(apiServiceProvider);

    accessibility.speak('$query aranıyor.', priority: TtsPriority.high);
    final search = await api.searchFoodByName(query: query);
    if (!mounted) return;

    if (!search.isSuccess || search.data == null) {
      accessibility.speakError(
        '$query bulunamadı. Farklı bir isim deneyebilir '
        'veya tara sekmesinden manuel ekleyebilirsiniz.',
      );
      return;
    }

    final food = search.data!;
    final label = food.foodNameTr;
    final calories = food.caloriesPer100g;

    accessibility.speak(
      '$label bulundu. 100 gramda ${calories.toStringAsFixed(0)} kalori. '
      '100 gram olarak kaydetmek için evet deyin, vazgeçmek için hayır deyin.',
      priority: TtsPriority.high,
    );

    // Kaydetmeden önce ayrı bir onay alınır; yanlış tanınan bir besin
    // sessizce günlüğe eklenmemeli.
    await ref.read(sttServiceProvider).startListening(
          onResult: (result) {
            if (!result.isFinal || !mounted) return;
            final intent = _voiceParser.parse(
              result.text,
              context: VoiceInteractionContext.scanConfirmation,
            );
            if (intent.action != ContextualVoiceAction.yes) {
              accessibility.speak('Kayıt iptal edildi.',
                  priority: TtsPriority.high);
              return;
            }
            unawaited(_saveFoodLog(label: label, foodName: query));
          },
          onError: (_) =>
              accessibility.speakError('Onay alınamadı, kaydedilmedi.'),
        );
  }

  Future<void> _saveFoodLog({
    required String label,
    required String foodName,
  }) async {
    final accessibility = ref.read(accessibilityServiceProvider);
    final result = await ref.read(apiServiceProvider).createManualFoodLog(
          captureId: 'voice_${DateTime.now().millisecondsSinceEpoch}',
          foodName: foodName.toLowerCase().replaceAll(' ', '_'),
          foodNameTr: label,
          portionValue: 100,
        );
    if (!mounted) return;

    if (!result.isSuccess) {
      accessibility.speakError(
        result.errorMessage ?? '$label kaydedilemedi.',
      );
      return;
    }
    unawaited(ref.read(historyControllerProvider.notifier).refresh());
    await AccessibilityUtils.successHaptic();
    accessibility.speak(
      '$label, 100 gram olarak günlüğünüze eklendi.',
      priority: TtsPriority.high,
    );
  }

  /// Sesle ölçüm kaydeder (kilo, uyku süresi).
  ///
  /// Değer komutun içinde söylenmişse ("kilomu kaydet yetmiş dört") doğrudan
  /// kaydeder; söylenmemişse ikinci bir dinleme turu açar. Böylece kullanıcı
  /// hiçbir aşamada klavyeye ihtiyaç duymaz.
  Future<void> _logMeasurement({
    required String rawText,
    required double min,
    required double max,
    required String unit,
    required String prompt,
    required void Function(double) onValue,
  }) async {
    final accessibility = ref.read(accessibilityServiceProvider);

    void apply(double value) {
      if (value < min || value > max) {
        accessibility.speakError(
          'Değer $min ile $max $unit arasında olmalıdır.',
        );
        return;
      }
      onValue(value);
      _onTabChanged(1);
      accessibility.speak(
        '${speakableNumber(value)} $unit olarak kaydedildi.',
        priority: TtsPriority.high,
      );
    }

    final inline = parseTurkishNumber(rawText);
    if (inline != null) {
      apply(inline);
      return;
    }

    // Sayı söylenmemiş; ikinci turda sadece değeri dinliyoruz.
    accessibility.speak(prompt, priority: TtsPriority.high);
    await ref.read(sttServiceProvider).startListening(
          onResult: (result) {
            if (!result.isFinal) return;
            final value = parseTurkishNumber(result.text);
            if (value == null) {
              accessibility.speakError(
                'Sayı anlaşılamadı. Aktivite ekranından da girebilirsiniz.',
              );
              return;
            }
            apply(value);
          },
          onError: (_) => accessibility.speakError(
            'Ses tanıma kullanılamıyor. Aktivite ekranından girebilirsiniz.',
          ),
        );
  }

  /// Bulunulan sekmeye göre kullanılabilir sesli komutları okur.
  void _announceHelp() {
    final context = HelpContext.fromTabIndex(ref.read(currentTabProvider));
    ref.read(voiceHelpServiceProvider).announce(context);
  }

  Future<void> _onTabChanged(int index) async {
    if (index == ref.read(currentTabProvider)) return;
    AccessibilityUtils.lightHaptic();
    ref.read(currentTabProvider.notifier).state = index;

    // Sekme değişince önceki sekmenin kalan cümleleri susar. Aksi hâlde
    // kullanıcı artık ekranda olmayan bir içeriği dinlemeye devam eder.
    final accessibility = ref.read(accessibilityServiceProvider);
    await accessibility.stop();
    await accessibility.speak(_tabs[index].ttsAnnouncement);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentTabProvider);
    final theme = Theme.of(context);
    // Tercih değişince sensör dinlemesi buna göre açılır/kapanır.
    _syncShakeDetector(ref.watch(shakeToListenProvider));

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(color: theme.scaffoldBackgroundColor),
          // Background Gradient Blur
          Positioned(
            top: -100,
            left: -100,
            child: CircleAvatar(
                radius: 200,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.05)),
          ),

          IndexedStack(
            index: currentIndex,
            children: [
              const FoodScanScreen(),
              const ActivityTrackerScreen(), // WaterTrackerScreen dosyasındaki yeni sınıf
              FoodHistoryScreen(onScanRequested: () => _onTabChanged(0)),
              const DiscoverScreen(),
              const DietitianScreen(),
            ],
          ),

          // TTS Failure Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ValueListenableBuilder<String?>(
                valueListenable:
                    ref.read(accessibilityServiceProvider).ttsFailureListenable,
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SettingsScreen()),
                            );
                          },
                          child: const Text('Ayarları Aç'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Voice Command Status Overlay
          if (_voiceStatus != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90, // Above the NavigationBar and FAB
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

      // Ekran okuyucu kullanıcısı için ana navigasyon: çubuğun kendisi kaç
      // sekme olduğunu duyurur, her sekme kendi sırasını ve seçili olup
      // olmadığını söyler. Görsel etiket tek başına yeterli değil.
      bottomNavigationBar: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Ana navigasyon çubuğu, ${_tabs.length} sekme',
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5))
            ],
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: _onTabChanged,
                height: 65,
                destinations: List.generate(_tabs.length, (index) {
                  final tab = _tabs[index];
                  final selected = index == currentIndex;
                  // "Tara sekmesi, seçili, 5 sekmeden 1."
                  final label = '${tab.label} sekmesi, '
                      '${selected ? 'seçili' : 'seçili değil'}, '
                      '${_tabs.length} sekmeden ${index + 1}.';
                  return NavigationDestination(
                    icon: Semantics(
                      label: label,
                      selected: selected,
                      excludeSemantics: true,
                      child: Icon(tab.icon, size: 22),
                    ),
                    selectedIcon: Semantics(
                      label: label,
                      selected: selected,
                      excludeSemantics: true,
                      child: Icon(tab.activeIcon,
                          color: theme.colorScheme.primary),
                    ),
                    label: tab.label,
                    tooltip: tab.label,
                  );
                }),
              ),
            ),
          ),
        ),
      ),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        // Yardım yalnızca sesle erişilebilir olmamalı: STT çalışmadığında ya da
        // kullanıcı komutu hatırlamadığında uzun basmak da yardımı okur.
        child: Semantics(
          button: true,
          label: _listeningState == ListeningState.listening
              ? 'Sesli komut butonu, dinleniyor. Durdurmak için çift dokunun.'
              : 'Sesli komut butonu. Komut söylemek için çift dokunun.',
          hint:
              'Kullanabileceğiniz komutları dinlemek için çift dokunup basılı tutun',
          onLongPress: _announceHelp,
          child: GestureDetector(
            onLongPress: _announceHelp,
            child: FloatingActionButton(
              onPressed: () => _voiceCmdService.toggleListening(),
              tooltip: 'Sesli komut. Uzun basınca yardım okunur.',
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                  _listeningState == ListeningState.listening
                      ? Icons.mic
                      : Icons.mic_none_rounded,
                  color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabInfo {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String ttsAnnouncement;
  const _TabInfo(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.ttsAnnouncement});
}
