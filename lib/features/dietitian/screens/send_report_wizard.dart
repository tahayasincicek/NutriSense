// =============================================================================
// lib/features/dietitian/screens/send_report_wizard.dart
// NutriSense — Diyetisyene Rapor Gönderme Sihirbazı
//
// 4 adımlı onay akışı (Wizard pattern):
//   1. Tarih aralığı seçimi
//   2. Özet önizleme (sesli okuma)
//   3. Onay ("Emin misiniz?")
//   4. Gönderim + sonuç
//
// Tüm adımlar sesli etiketlenmiş ve TTS ile okunur.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/accessible_button.dart';

/// Rapor türü seçenekleri
enum ReportRange {
  daily('Günlük', 'daily', 1),
  weekly('Haftalık', 'weekly', 7),
  monthly('Aylık', 'monthly', 30);

  const ReportRange(this.label, this.apiValue, this.days);
  final String label;
  final String apiValue;
  final int days;
}

class SendReportWizard extends ConsumerStatefulWidget {
  const SendReportWizard({super.key});

  @override
  ConsumerState<SendReportWizard> createState() => _SendReportWizardState();
}

class _SendReportWizardState extends ConsumerState<SendReportWizard> {
  late AccessibilityService _accessibility;
  late ApiService _apiService;

  // ── Wizard durumu ──
  int _currentStep = 0;
  ReportRange _selectedRange = ReportRange.weekly;
  String? _userMessage;
  bool _isSending = false;
  bool _isSent = false;
  String _resultMessage = '';

  // Hesaplanan tarihler
  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _apiService = ref.read(apiServiceProvider);

    _toDate = DateTime.now();
    _fromDate = _toDate.subtract(Duration(days: _selectedRange.days));

    // Ekran duyurusu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibility.speak(
        'Diyetisyene rapor gönderme sihirbazı. '
        'İlk adım: tarih aralığını seçin.',
        priority: TtsPriority.high,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapor Gönder'),
        leading: Semantics(
          label: 'Geri dön',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_currentStep > 0 && !_isSent) {
                _goBack();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      ),
      body: Column(
        children: [
          // ── İlerleme göstergesi ──
          _buildStepIndicator(theme),

          // ── Adım içeriği ──
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStep(theme),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // İLERLEME GÖSTERGESİ
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStepIndicator(ThemeData theme) {
    final steps = ['Tarih', 'Önizleme', 'Onay', 'Gönderim'];

    return Semantics(
      label:
          'Adım ${_currentStep + 1} / ${steps.length}: ${steps[_currentStep]}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: List.generate(steps.length, (i) {
            final isActive = i == _currentStep;
            final isDone = i < _currentStep;

            return Expanded(
              child: Row(
                children: [
                  // Numara dairesi
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? AppTheme.primaryColor
                          : isActive
                              ? AppTheme.primaryColor
                              : Colors.grey[300],
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color:
                                    isActive ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  // Bağlantı çizgisi
                  if (i < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color:
                            isDone ? AppTheme.primaryColor : Colors.grey[300],
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADIM İÇERİKLERİ
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCurrentStep(ThemeData theme) {
    return switch (_currentStep) {
      0 => _buildStep1DateSelection(theme),
      1 => _buildStep2Preview(theme),
      2 => _buildStep3Confirmation(theme),
      3 => _buildStep4Result(theme),
      _ => const SizedBox.shrink(),
    };
  }

  // ── ADIM 1: Tarih aralığı seçimi ──
  Widget _buildStep1DateSelection(ThemeData theme) {
    return Padding(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Hangi tarih aralığını göndermek istiyorsunuz?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Rapor türü seçim kartları
          ...ReportRange.values.map((range) {
            final isActive = _selectedRange == range;
            final fromDt = _toDate.subtract(Duration(days: range.days));
            final label = '${fromDt.day}.${fromDt.month}.${fromDt.year} — '
                '${_toDate.day}.${_toDate.month}.${_toDate.year}';

            return Semantics(
              label: '${range.label} rapor. $label. '
                  '${isActive ? "Seçili." : "Seçmek için dokunun."}',
              selected: isActive,
              button: true,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRange = range;
                    _fromDate = fromDt;
                  });
                  _accessibility.speak(
                    '${range.label} rapor seçildi. $label',
                    priority: TtsPriority.normal,
                  );
                  _accessibility.lightHaptic();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          isActive ? AppTheme.primaryColor : Colors.grey[300]!,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color:
                            isActive ? AppTheme.primaryColor : Colors.grey[400],
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              range.label,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? AppTheme.primaryColor
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(label,
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Not alanı
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Diyetisyeninize not (opsiyonel)',
              hintText: 'Eklemek istediğiniz bir mesaj...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 2,
            onChanged: (v) => _userMessage = v.isEmpty ? null : v,
          ),

          const Spacer(),
          _buildNavigationButtons(showBack: false),
        ],
      ),
    );
  }

  // ── ADIM 2: Önizleme ──
  Widget _buildStep2Preview(ThemeData theme) {
    final summary = '${_selectedRange.label} rapor. '
        '${_fromDate.day}.${_fromDate.month}.${_fromDate.year} — '
        '${_toDate.day}.${_toDate.month}.${_toDate.year}. ';

    return Padding(
      key: const ValueKey('step2'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Rapor Önizlemesi',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Özet kartı
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                    Icons.date_range, 'Rapor Türü', _selectedRange.label),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.calendar_today, 'Başlangıç',
                    '${_fromDate.day}.${_fromDate.month}.${_fromDate.year}'),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.calendar_today, 'Bitiş',
                    '${_toDate.day}.${_toDate.month}.${_toDate.year}'),
                if (_userMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.message, 'Not', _userMessage!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sesli okuma butonu
          Semantics(
            label: 'Rapor özetini sesli oku',
            button: true,
            child: OutlinedButton.icon(
              onPressed: () {
                _accessibility.speak(summary, priority: TtsPriority.high);
              },
              icon: const Icon(Icons.volume_up),
              label: const Text('Sesli Oku', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ),

          const Spacer(),
          _buildNavigationButtons(showBack: true),
        ],
      ),
    );
  }

  // ── ADIM 3: Onay ──
  Widget _buildStep3Confirmation(ThemeData theme) {
    return Padding(
      key: const ValueKey('step3'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.send_rounded,
              size: 80, color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(
              'Göndermek istediğinizden emin misiniz?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_selectedRange.label} beslenme raporunuz diyetisyeninize '
            'e-posta ve SMS ile iletilecektir.',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // Evet / Hayır butonları
          Row(
            children: [
              Expanded(
                child: AccessibleButton(
                  label: 'Hayır, Vazgeç',
                  semanticLabel: 'Gönderme işlemini iptal et ve geri dön',
                  icon: Icons.close,
                  type: AccessibleButtonType.outlined,
                  onPressed: _goBack,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AccessibleButton(
                  label: 'Evet, Gönder',
                  semanticLabel: 'Raporu diyetisyene gönder',
                  icon: Icons.send,
                  type: AccessibleButtonType.filled,
                  onPressed: _sendReport,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ADIM 4: Sonuç ──
  Widget _buildStep4Result(ThemeData theme) {
    return Padding(
      key: const ValueKey('step4'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSending) ...[
            const CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            const Text(
              'Rapor gönderiliyor...',
              style: TextStyle(fontSize: 18),
            ),
          ] else ...[
            Icon(
              _isSent ? Icons.check_circle : Icons.error_outline,
              size: 80,
              color: _isSent ? AppTheme.primaryColor : Colors.red[400],
            ),
            const SizedBox(height: 24),
            Text(
              _isSent ? 'Rapor Gönderildi!' : 'Gönderim Başarısız',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: _isSent ? AppTheme.primaryColor : Colors.red[400],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _resultMessage,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            AccessibleButton(
              label: _isSent ? 'Tamam' : 'Tekrar Dene',
              semanticLabel:
                  _isSent ? 'Ekranı kapat' : 'Rapor gönderimini tekrar dene',
              icon: _isSent ? Icons.check : Icons.refresh,
              type: AccessibleButtonType.filled,
              onPressed: () {
                if (_isSent) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _currentStep = 2);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // YARDIMCI WİDGET'LAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 15, color: Colors.black87)),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons({required bool showBack}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          if (showBack) ...[
            Expanded(
              child: AccessibleButton(
                label: 'Geri',
                semanticLabel: 'Önceki adıma dön',
                icon: Icons.arrow_back,
                type: AccessibleButtonType.outlined,
                onPressed: _goBack,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: AccessibleButton(
              label: 'İleri',
              semanticLabel: 'Sonraki adıma geç',
              icon: Icons.arrow_forward,
              type: AccessibleButtonType.filled,
              onPressed: _goNext,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVİGASYON
  // ═══════════════════════════════════════════════════════════════════════════

  void _goNext() {
    if (_currentStep >= 3) return;
    setState(() => _currentStep++);

    final announcements = [
      '', // 0 dan 1'e
      'Rapor önizlemesi. Bilgileri kontrol edin ve devam edin.',
      'Son adım. Göndermek istediğinizden emin misiniz?',
      'Gönderiliyor.',
    ];

    if (_currentStep < announcements.length) {
      _accessibility.speak(
        announcements[_currentStep],
        priority: TtsPriority.high,
      );
    }
    _accessibility.lightHaptic();
  }

  void _goBack() {
    if (_currentStep <= 0) return;
    setState(() => _currentStep--);
    _accessibility.speak('Önceki adıma dönüldü.', priority: TtsPriority.normal);
    _accessibility.lightHaptic();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GÖNDERİM
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _sendReport() async {
    setState(() {
      _currentStep = 3;
      _isSending = true;
    });

    _accessibility.speak(
      'Raporunuz gönderiliyor, lütfen bekleyin.',
      priority: TtsPriority.high,
    );

    final result = await _apiService.sendToDietitian(
      consent: true,
      reportType: _selectedRange.apiValue,
      fromDate: _fromDate,
      toDate: _toDate,
      message: _userMessage,
    );

    setState(() {
      _isSending = false;
      _isSent = result.isSuccess;
      _resultMessage = result.isSuccess
          ? result.data?.message ??
              AppStrings.dietitianReportSent('diyetisyeninize')
          : result.errorMessage ?? AppStrings.dietitianReportFailed;
    });

    if (_isSent) {
      _accessibility.speak(
        _resultMessage,
        priority: TtsPriority.high,
      );
      _accessibility.successHaptic();
    } else {
      _accessibility.speak(
        _resultMessage,
        priority: TtsPriority.critical,
      );
      _accessibility.errorHaptic();
    }
  }
}
