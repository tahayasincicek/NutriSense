// =============================================================================
// lib/features/settings/screens/accessibility_settings_screen.dart
// NutriSense — Erişilebilirlik Ayarları Ekranı
//
// Görme engelli kullanıcılar için tam erişilebilir ayar ekranı.
// Tüm kontroller Semantics ile etiketlenmiş.
// Her değişiklikte anında TTS önizlemesi çalar.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/widgets/accessible_button.dart';

class AccessibilitySettingsScreen extends ConsumerStatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  ConsumerState<AccessibilitySettingsScreen> createState() =>
      _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState
    extends ConsumerState<AccessibilitySettingsScreen> {
  late AccessibilityService _accessibility;

  // Yerel state
  late double _speechRate;
  late double _pitch;
  late double _volume;
  late bool _vibrationEnabled;
  late double _autoReadDelay;
  late bool _highContrast;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);

    // Mevcut ayarları yükle
    _speechRate = _accessibility.speechRate;
    _pitch = _accessibility.pitch;
    _volume = _accessibility.volume;
    _vibrationEnabled = _accessibility.vibrationEnabled;
    _autoReadDelay = _accessibility.autoReadDelay;
    _highContrast = _accessibility.highContrast;

    // Ekran açılış duyurusu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibility.speak(
        AppStrings.screenSettings,
        priority: TtsPriority.normal,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Erişilebilirlik Ayarları'),
        actions: [
          // Kaydet butonu
          Semantics(
            label: 'Ayarları kaydet',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.check, size: 28),
              onPressed: _saveSettings,
              tooltip: 'Kaydet',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ════════════════════════════════════════════════════════════════════
          // KONUŞMA HIZI
          // ════════════════════════════════════════════════════════════════════
          _buildSectionHeader(
            title: AppStrings.settingsSpeechRate,
            icon: Icons.speed,
          ),
          const SizedBox(height: 8),
          _buildSlider(
            semanticLabel: 'Konuşma hızı ayarı. '
                'Şu an ${_speedLabel(_speechRate)}. '
                'Sola kaydırarak yavaşlatın, sağa kaydırarak hızlandırın.',
            value: _speechRate,
            min: 0.1,
            max: 0.9,
            divisions: 8,
            label: _speedLabel(_speechRate),
            onChanged: (value) {
              setState(() => _speechRate = value);
            },
            onChangeEnd: (value) async {
              await _accessibility.setSpeechRate(value);
              _accessibility.speak(
                AppStrings.settingsSpeedPreview(_speedLabel(value)),
                priority: TtsPriority.high,
              );
            },
          ),
          _buildValueChips(
            current: _speechRate,
            values: {
              0.2: 'Yavaş',
              0.4: 'Normal',
              0.6: 'Hızlı',
              0.8: 'Çok Hızlı',
            },
            onSelected: (value) async {
              setState(() => _speechRate = value);
              await _accessibility.setSpeechRate(value);
              _accessibility.speak(
                AppStrings.settingsSpeedPreview(_speedLabel(value)),
                priority: TtsPriority.high,
              );
            },
          ),
          const Divider(height: 32),

          // ════════════════════════════════════════════════════════════════════
          // SES TONU
          // ════════════════════════════════════════════════════════════════════
          _buildSectionHeader(
            title: AppStrings.settingsPitch,
            icon: Icons.tune,
          ),
          const SizedBox(height: 8),
          _buildSlider(
            semanticLabel: 'Ses tonu ayarı. '
                'Şu an ${_pitchLabel(_pitch)}. '
                'Sola kaydırarak kalınlaştırın, sağa kaydırarak inceleştirin.',
            value: _pitch,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            label: _pitchLabel(_pitch),
            onChanged: (value) {
              setState(() => _pitch = value);
            },
            onChangeEnd: (value) async {
              await _accessibility.setPitch(value);
              _accessibility.speak(
                AppStrings.settingsPitchPreview(_pitchLabel(value)),
                priority: TtsPriority.high,
              );
            },
          ),
          _buildValueChips(
            current: _pitch,
            values: {
              0.7: 'Kalın',
              1.0: 'Normal',
              1.3: 'İnce',
              1.6: 'Çok İnce',
            },
            onSelected: (value) async {
              setState(() => _pitch = value);
              await _accessibility.setPitch(value);
              _accessibility.speak(
                AppStrings.settingsPitchPreview(_pitchLabel(value)),
                priority: TtsPriority.high,
              );
            },
          ),
          const Divider(height: 32),

          // ════════════════════════════════════════════════════════════════════
          // SES SEVİYESİ
          // ════════════════════════════════════════════════════════════════════
          _buildSectionHeader(
            title: AppStrings.settingsVolume,
            icon: Icons.volume_up,
          ),
          const SizedBox(height: 8),
          _buildSlider(
            semanticLabel: 'Ses seviyesi ayarı. '
                'Şu an yüzde ${(_volume * 100).toInt()}.',
            value: _volume,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            label: '%${(_volume * 100).toInt()}',
            onChanged: (value) {
              setState(() => _volume = value);
            },
            onChangeEnd: (value) async {
              await _accessibility.setVolume(value);
              _accessibility.speak(
                'Ses seviyesi yüzde ${(value * 100).toInt()} olarak ayarlandı.',
                priority: TtsPriority.high,
              );
            },
          ),
          const Divider(height: 32),

          // ════════════════════════════════════════════════════════════════════
          // TİTREŞİM
          // ════════════════════════════════════════════════════════════════════
          _buildSectionHeader(
            title: AppStrings.settingsVibration,
            icon: Icons.vibration,
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Titreşim ${_vibrationEnabled ? "açık" : "kapalı"}. '
                'Değiştirmek için çift dokunun.',
            toggled: _vibrationEnabled,
            onTapHint: 'Değiştirmek için çift dokunun',
            onTap: () async {
              final newValue = !_vibrationEnabled;
              setState(() => _vibrationEnabled = newValue);
              await _accessibility.setVibrationEnabled(newValue);

              final text =
                  newValue ? 'Titreşim açıldı.' : 'Titreşim kapatıldı.';
              _accessibility.speak(text, priority: TtsPriority.high);

              if (newValue) {
                _accessibility.mediumHaptic();
              }
            },
            child: SwitchListTile(
              title: Text(
                _vibrationEnabled ? 'Titreşim Açık' : 'Titreşim Kapalı',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              subtitle: const Text('Dokunma ve komut geri bildirimi'),
              value: _vibrationEnabled,
              activeThumbColor: AppTheme.primaryColor,
              onChanged: (value) async {
                setState(() => _vibrationEnabled = value);
                await _accessibility.setVibrationEnabled(value);

                final text = value ? 'Titreşim açıldı.' : 'Titreşim kapatıldı.';
                _accessibility.speak(text, priority: TtsPriority.high);

                if (value) {
                  _accessibility.mediumHaptic();
                }
              },
            ),
          ),
          const Divider(height: 32),

          // ════════════════════════════════════════════════════════════════════
          // OTOMATİK OKUMA GECİKMESİ
          // ════════════════════════════════════════════════════════════════════
          _buildSectionHeader(
            title: AppStrings.settingsAutoReadDelay,
            icon: Icons.timer,
          ),
          const SizedBox(height: 8),
          _buildSlider(
            semanticLabel: 'Ekran değiştiğinde otomatik okuma gecikmesi. '
                'Şu an ${_autoReadDelay.toStringAsFixed(1)} saniye.',
            value: _autoReadDelay,
            min: 0.0,
            max: 3.0,
            divisions: 6,
            label: '${_autoReadDelay.toStringAsFixed(1)} sn',
            onChanged: (value) {
              setState(() => _autoReadDelay = value);
            },
            onChangeEnd: (value) async {
              await _accessibility.setAutoReadDelay(value);
              _accessibility.speak(
                'Gecikme ${value.toStringAsFixed(1)} saniye olarak ayarlandı.',
                priority: TtsPriority.normal,
              );
            },
          ),
          const Divider(height: 32),

          // ════════════════════════════════════════════════════════════════════
          // YÜKSEK KONTRAST
          // ════════════════════════════════════════════════════════════════════
          _buildSectionHeader(
            title: AppStrings.settingsHighContrast,
            icon: Icons.contrast,
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Yüksek kontrast ${_highContrast ? "açık" : "kapalı"}. '
                'Değiştirmek için çift dokunun.',
            toggled: _highContrast,
            onTapHint: 'Değiştirmek için çift dokunun',
            onTap: () async {
              final newValue = !_highContrast;
              setState(() => _highContrast = newValue);
              await _accessibility.setHighContrast(newValue);
              _accessibility.speak(
                newValue
                    ? 'Yüksek kontrast açıldı.'
                    : 'Yüksek kontrast kapatıldı.',
                priority: TtsPriority.high,
              );
            },
            child: SwitchListTile(
              title: Text(
                _highContrast
                    ? 'Yüksek Kontrast Açık'
                    : 'Yüksek Kontrast Kapalı',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              subtitle: const Text('Metin ve arka plan kontrastını artırır'),
              value: _highContrast,
              activeThumbColor: AppTheme.primaryColor,
              onChanged: (value) async {
                setState(() => _highContrast = value);
                await _accessibility.setHighContrast(value);

                _accessibility.speak(
                  value
                      ? 'Yüksek kontrast açıldı.'
                      : 'Yüksek kontrast kapatıldı.',
                  priority: TtsPriority.high,
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // ════════════════════════════════════════════════════════════════════
          // TEST VE KAYDET
          // ════════════════════════════════════════════════════════════════════
          AccessibleButton(
            label: 'Sesi Test Et',
            semanticLabel: 'Mevcut ses ayarlarını test et. '
                'Bir örnek cümle sesli okunacak.',
            icon: Icons.play_circle_outline,
            type: AccessibleButtonType.outlined,
            onPressed: () {
              _accessibility.speak(
                'Bu bir test cümlesidir. '
                'Konuşma hızı ${_speedLabel(_speechRate)}, '
                'ses tonu ${_pitchLabel(_pitch)}, '
                'ses seviyesi yüzde ${(_volume * 100).toInt()}.',
                priority: TtsPriority.high,
              );
            },
          ),
          const SizedBox(height: 16),
          AccessibleButton(
            label: 'Ayarları Kaydet',
            semanticLabel: 'Tüm erişilebilirlik ayarlarını kaydet',
            icon: Icons.save,
            type: AccessibleButtonType.filled,
            onPressed: _saveSettings,
          ),
          const SizedBox(height: 16),
          AccessibleButton(
            label: 'Varsayılanlara Dön',
            semanticLabel: 'Tüm ayarları fabrika varsayılanlarına sıfırla',
            icon: Icons.restart_alt,
            type: AccessibleButtonType.outlined,
            onPressed: _resetDefaults,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // YARDIMCI WİDGET'LAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String semanticLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Semantics(
      label: semanticLabel,
      slider: true,
      value: label,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
          trackHeight: 6,
          activeTrackColor: AppTheme.primaryColor,
          inactiveTrackColor: AppTheme.primaryColor.withOpacity(0.2),
          thumbColor: AppTheme.primaryColor,
          valueIndicatorTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ),
    );
  }

  Widget _buildValueChips({
    required double current,
    required Map<double, String> values,
    required Function(double) onSelected,
  }) {
    return Wrap(
      spacing: 8,
      children: values.entries.map((entry) {
        final isActive = (current - entry.key).abs() < 0.05;
        return Semantics(
          label: '${entry.value}${isActive ? ", seçili" : ""}',
          button: true,
          selected: isActive,
          child: ChoiceChip(
            label: Text(
              entry.value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : AppTheme.primaryDark,
              ),
            ),
            selected: isActive,
            selectedColor: AppTheme.primaryColor,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onSelected: (_) => onSelected(entry.key),
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AKSIYONLAR
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveSettings() async {
    await _accessibility.setSpeechRate(_speechRate);
    await _accessibility.setPitch(_pitch);
    await _accessibility.setVolume(_volume);
    await _accessibility.setVibrationEnabled(_vibrationEnabled);
    await _accessibility.setAutoReadDelay(_autoReadDelay);
    await _accessibility.setHighContrast(_highContrast);

    _accessibility.speak(
      AppStrings.settingsSaved,
      priority: TtsPriority.high,
    );
    _accessibility.successHaptic();
  }

  Future<void> _resetDefaults() async {
    setState(() {
      _speechRate = 0.5;
      _pitch = 1.0;
      _volume = 1.0;
      _vibrationEnabled = true;
      _autoReadDelay = 0.5;
      _highContrast = true;
    });

    await _saveSettings();
    _accessibility.speak(
      'Ayarlar varsayılan değerlere sıfırlandı.',
      priority: TtsPriority.high,
    );
  }

  String _speedLabel(double rate) {
    final display = 0.5 + (rate * 1.5);
    return '${display.toStringAsFixed(1)}x';
  }

  String _pitchLabel(double pitch) {
    if (pitch < 0.8) return 'Kalın';
    if (pitch < 1.2) return 'Normal';
    if (pitch < 1.5) return 'İnce';
    return 'Çok İnce';
  }
}
