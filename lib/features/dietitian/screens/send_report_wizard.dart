import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/auth_model.dart';
import '../../../shared/models/food_analysis_model.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/contextual_voice_command.dart';
import '../../../shared/services/stt_service.dart';
import '../../../shared/widgets/accessible_button.dart';

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
  const SendReportWizard({required this.assignment, super.key});

  final DietitianAssignmentInfo assignment;

  @override
  ConsumerState<SendReportWizard> createState() => _SendReportWizardState();
}

class _SendReportWizardState extends ConsumerState<SendReportWizard> {
  final _noteController = TextEditingController();
  final _uuid = const Uuid();
  late final AccessibilityService _accessibility;
  late final SttService _stt;
  static const _voiceParser = ContextualVoiceCommandParser();
  final _voiceConfirmation = VoiceConfirmationGate();
  ReportRange _range = ReportRange.weekly;
  late DateTime _toDate;
  late DateTime _fromDate;
  late Set<String> _channels;
  int _step = 0;
  bool _loadingPreview = false;
  bool _sending = false;
  bool _explicitConsent = false;
  String? _error;
  String? _idempotencyKey;
  DietitianReportPreview? _preview;
  SendToDietitianResult? _result;
  String? _voiceStatus;
  bool _voiceListening = false;

  ApiService get _api => ref.read(apiServiceProvider);

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _stt = ref.read(sttServiceProvider);
    _toDate = DateTime.now();
    _setRangeDates();
    _channels = {
      if (widget.assignment.emailVerified) 'email',
      if (!widget.assignment.emailVerified && widget.assignment.phoneVerified)
        'sms',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibility.speak(
        'Diyetisyen raporu. Önce dönem ve doğrulanmış gönderim kanallarını seçin.',
        priority: TtsPriority.high,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accessibility
        .setScreenReaderActive(MediaQuery.of(context).accessibleNavigation);
  }

  void _setRangeDates() {
    _fromDate = DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
    ).subtract(Duration(days: _range.days - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporu Önizle ve Gönder'),
        leading: IconButton(
          tooltip: _step > 0 && _step < 3 ? 'Önceki adıma dön' : 'Kapat',
          onPressed: _step > 0 && _step < 3
              ? () => setState(() => _step -= 1)
              : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StepIndicator(step: _step),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: MaterialBanner(
                  content: Text(_error!),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _error = null),
                      child: const Text('Kapat'),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() => switch (_step) {
        0 => _selectionStep(),
        1 => _previewStep(),
        2 => _consentStep(),
        _ => _resultStep(),
      };

  Widget _selectionStep() {
    return ListView(
      key: const Key('report_selection_step'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Dönem ve kanallar',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Alıcı ${widget.assignment.dietitianName}. İletişim bilgileri güvenlik için maskelenmiştir.',
        ),
        const SizedBox(height: 16),
        SegmentedButton<ReportRange>(
          key: const Key('report_range_selector'),
          segments: ReportRange.values
              .map((range) => ButtonSegment(
                    value: range,
                    label: Text(range.label),
                  ))
              .toList(),
          selected: {_range},
          onSelectionChanged: (selection) {
            setState(() {
              _range = selection.single;
              _setRangeDates();
              _invalidatePreview();
            });
          },
        ),
        const Divider(),
        CheckboxListTile(
          key: const Key('report_channel_email'),
          value: _channels.contains('email'),
          onChanged: widget.assignment.emailVerified
              ? (value) => _toggleChannel('email', value ?? false)
              : null,
          title: const Text('E-posta'),
          subtitle: Text(widget.assignment.emailVerified
              ? widget.assignment.emailMasked ?? 'Maskeli adres'
              : 'E-posta doğrulanmamış'),
        ),
        CheckboxListTile(
          key: const Key('report_channel_sms'),
          value: _channels.contains('sms'),
          onChanged: widget.assignment.phoneVerified
              ? (value) => _toggleChannel('sms', value ?? false)
              : null,
          title: const Text('SMS — ayrıntılı besin kayıtları'),
          subtitle: Text(widget.assignment.phoneVerified
              ? widget.assignment.phoneMasked ?? 'Maskeli telefon'
              : 'Telefon doğrulanmamış'),
        ),
        const Text(
          'SMS içinde besin adları, gram miktarları, tarih-saat ve kaloriler '
          'paylaşılır. Uzun raporlar numaralı mesajlara bölünür; '
          'operatör ek SMS ücreti uygulayabilir.',
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('report_note'),
          controller: _noteController,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Diyetisyene not (isteğe bağlı)',
            helperText: 'Kişisel veya gereksiz hassas bilgi yazmayın.',
          ),
          onChanged: (_) => _invalidatePreview(),
        ),
        const SizedBox(height: 20),
        AccessibleButton(
          key: const Key('report_preview_button'),
          label: _loadingPreview
              ? 'Önizleme hazırlanıyor'
              : 'Gerçek Kayıtları Önizle',
          icon: Icons.preview_outlined,
          onPressed: _loadingPreview ? null : _loadPreview,
        ),
      ],
    );
  }

  Widget _previewStep() {
    final preview = _preview!;
    return ListView(
      key: const Key('report_preview_step'),
      padding: const EdgeInsets.all(20),
      children: [
        Semantics(
          label: preview.accessibilitySummary,
          container: true,
          child: ExcludeSemantics(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Erişilebilir gönderim özeti',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text('Alıcı: ${preview.dietitianName}'),
                    for (final channel in preview.channels)
                      Text('${_channelLabel(channel)}: '
                          '${preview.recipients[channel]}'),
                    Text('Dönem: ${_date(preview.fromDate)} – '
                        '${_date(preview.toDate)}'),
                    Text('${preview.recordCount} kullanıcı onaylı kayıt'),
                    Text(
                        'Toplam ${preview.totalCalories.toStringAsFixed(0)} kcal; '
                        'günlük ortalama '
                        '${preview.averageDailyCalories.toStringAsFixed(0)} kcal'),
                    Text('${preview.estimatedPortionCount} tahmini porsiyon'),
                    const SizedBox(height: 8),
                    const Text(
                        'Tahmini beslenme bilgisidir; tıbbi tavsiye değildir.'),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('report_listen_preview'),
          onPressed: () => _accessibility.speak(
            preview.accessibilitySummary,
            priority: TtsPriority.high,
            allowWhileScreenReaderActive: true,
          ),
          icon: const Icon(Icons.volume_up),
          label: const Text('Özeti Dinle'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('Değiştir'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const Key('report_continue_to_consent'),
                onPressed: () => setState(() => _step = 2),
                child: const Text('Onaya Geç'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _consentStep() {
    final preview = _preview!;
    return ListView(
      key: const Key('report_consent_step'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Her gönderim için açık onay',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(preview.accessibilitySummary),
        const SizedBox(height: 16),
        CheckboxListTile(
          key: const Key('report_explicit_consent'),
          value: _explicitConsent,
          onChanged: _sending
              ? null
              : (value) => setState(() => _explicitConsent = value ?? false),
          title: const Text(
            'Okunan dönem, kayıt sayısı, alıcı ve seçilen kanallarda besin adı, '
            'miktar, tarih-saat ve kalori paylaşımını bu gönderim için '
            'açıkça onaylıyorum.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_voiceStatus != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            label: _voiceStatus,
            child: Text(
              _voiceStatus!,
              key: const Key('report_voice_status'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        AccessibleButton(
          key: const Key('report_voice_command_button'),
          label: _voiceListening
              ? 'Dinleniyor'
              : _voiceConfirmation.isActive
                  ? 'Sesli İkinci Onayı Ver'
                  : 'Sesli Rapor Komutu',
          semanticLabel: _voiceConfirmation.isActive
              ? 'Rapor gönderimini ikinci kez onaylamak için evet, iptal etmek için hayır söyleyin'
              : 'Rapor göndermek için rapor gönder deyin. Gönderimden önce ikinci onay istenir.',
          icon: _voiceListening ? Icons.mic : Icons.mic_none,
          type: AccessibleButtonType.outlined,
          onPressed:
              _voiceListening || _sending ? null : _listenForReportCommand,
        ),
        const SizedBox(height: 20),
        AccessibleButton(
          key: const Key('report_send_button'),
          label: _sending ? 'Gönderim işleniyor' : 'Onayla ve Güvenli Gönder',
          icon: Icons.send_outlined,
          onPressed: !_explicitConsent || _sending ? null : _send,
        ),
      ],
    );
  }

  Widget _resultStep() {
    final result = _result;
    final complete = result?.status == 'sent';
    final partial = result?.status == 'partial_failed';
    return ListView(
      key: const Key('report_result_step'),
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          complete
              ? Icons.check_circle
              : partial
                  ? Icons.warning_amber_rounded
                  : Icons.error_outline,
          size: 72,
          color: complete
              ? Colors.green
              : partial
                  ? Colors.orange
                  : Colors.red,
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            result?.message ?? _error ?? 'Gönderim başlatılamadı.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 16),
        if (result != null)
          for (final delivery in result.channels)
            ListTile(
              leading: Icon(delivery.isSent ? Icons.check : Icons.close),
              title: Text('${delivery.channelLabel}: ${delivery.status}'),
              subtitle: Text('${delivery.destinationMasked}; '
                  'deneme ${delivery.attemptCount}/${delivery.maxAttempts}'
                  '${delivery.errorCode == null ? '' : '; ${delivery.errorCode}'}'),
            ),
        const Text(
          '“Gönderildi”, sağlayıcının mesajı kabul ettiğini gösterir; '
          'alıcının okuduğunu veya nihai teslimi kanıtlamaz.',
        ),
        const SizedBox(height: 24),
        if (result?.channels.any((item) => item.canRetry) ?? false)
          AccessibleButton(
            key: const Key('report_retry_button'),
            label: 'Başarısız Kanalları Yeniden Dene',
            icon: Icons.refresh,
            onPressed: _sending ? null : _retry,
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }

  void _toggleChannel(String channel, bool selected) {
    setState(() {
      if (selected) {
        _channels.add(channel);
      } else {
        _channels.remove(channel);
      }
      _invalidatePreview();
    });
  }

  void _invalidatePreview() {
    _preview = null;
    _idempotencyKey = null;
    _explicitConsent = false;
  }

  Future<void> _loadPreview() async {
    if (_channels.isEmpty) {
      _showError('En az bir doğrulanmış gönderim kanalı seçin.');
      return;
    }
    setState(() {
      _loadingPreview = true;
      _error = null;
    });
    final result = await _api.previewDietitianReport(
      channels: _channels.toList(),
      reportType: _range.apiValue,
      fromDate: _fromDate,
      toDate: _toDate,
      message: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _loadingPreview = false;
      if (result.isSuccess && result.data != null) {
        _preview = result.data;
        _idempotencyKey = _uuid.v4();
        _step = 1;
      } else {
        _error = result.errorMessage ?? 'Rapor önizlemesi hazırlanamadı.';
      }
    });
    if (_preview != null) {
      _accessibility.speak(
        _preview!.accessibilitySummary,
        priority: TtsPriority.high,
      );
    }
  }

  Future<void> _send() async {
    if (_preview == null || _idempotencyKey == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await _api.sendToDietitian(
      consent: true,
      channels: _preview!.channels,
      consentContextHash: _preview!.consentContextHash,
      idempotencyKey: _idempotencyKey!,
      reportType: _range.apiValue,
      fromDate: _fromDate,
      toDate: _toDate,
      message: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _explicitConsent = false;
      if (result.isSuccess && result.data != null) {
        _result = result.data;
      } else {
        _error = result.errorMessage ?? 'Gönderim başlatılamadı.';
      }
      _step = 3;
    });
    final spoken = _result?.message ?? _error!;
    _accessibility.speak(spoken, priority: TtsPriority.high);
  }

  Future<void> _listenForReportCommand() async {
    await _accessibility.prepareForSpeechInput();
    await _stt.startListening(
      listenFor: const Duration(seconds: 8),
      onListeningStarted: () {
        if (!mounted) return;
        setState(() {
          _voiceListening = true;
          _voiceStatus = _voiceConfirmation.isActive
              ? 'Dinleniyor. Gönderimi onaylamak için evet, vazgeçmek için hayır söyleyin.'
              : 'Dinleniyor. Rapor gönder deyin.';
        });
        _accessibility.mediumHaptic();
      },
      onListeningStopped: () {
        _accessibility.finishSpeechInput();
        if (mounted) setState(() => _voiceListening = false);
      },
      onResult: (result) {
        if (!result.isFinal) return;
        _accessibility.finishSpeechInput();
        final confirmationActive = _voiceConfirmation.isActive;
        final intent = _voiceParser.parse(
          result.text,
          context: confirmationActive
              ? VoiceInteractionContext.reportSendConfirmation
              : VoiceInteractionContext.reportConsent,
        );
        if (confirmationActive) {
          final resolved = _voiceConfirmation.resolve(intent);
          if (resolved == ContextualVoiceAction.sendReport) {
            setState(() {
              _explicitConsent = true;
              _voiceStatus = 'İkinci sesli onay alındı. Gönderim başlatılıyor.';
            });
            _accessibility.successHaptic();
            _send();
            return;
          }
          setState(() => _voiceStatus =
              'Gönderim onaylanmadı. Rapor gönderilmedi. Dokunmatik onay seçeneği kullanılabilir.');
          _accessibility.errorHaptic();
          return;
        }
        if (intent.accepted &&
            intent.action == ContextualVoiceAction.sendReport &&
            intent.requiresSecondConfirmation) {
          _voiceConfirmation.request(ContextualVoiceAction.sendReport);
          setState(() => _voiceStatus =
              'Kritik işlem. Göndermek için sesli komut düğmesine yeniden basıp evet söyleyin.');
          _accessibility.doubleHaptic();
          return;
        }
        if (intent.accepted && intent.action == ContextualVoiceAction.back) {
          setState(() => _step = 1);
          return;
        }
        setState(() => _voiceStatus =
            'Komut güvenli biçimde reddedildi. Tam olarak rapor gönder deyin veya dokunmatik düğmeyi kullanın.');
        _accessibility.errorHaptic();
      },
      onError: (message) {
        _accessibility.finishSpeechInput();
        if (!mounted) return;
        setState(() {
          _voiceListening = false;
          _voiceStatus =
              '$message. Mikrofon olmadan onay kutusu ve gönder düğmesi kullanılabilir.';
        });
        _accessibility.errorHaptic();
      },
    );
  }

  Future<void> _retry() async {
    final reportId = _result?.reportId;
    if (reportId == null || _sending) return;
    setState(() => _sending = true);
    final retried = await _api.retryDietitianReport(reportId: reportId);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (retried.isSuccess && retried.data != null) {
        _result = retried.data;
      } else {
        _error = retried.errorMessage ?? 'Yeniden deneme başlatılamadı.';
      }
    });
  }

  void _showError(String message) {
    setState(() => _error = message);
    _accessibility.speak(message, priority: TtsPriority.critical);
  }

  String _channelLabel(String value) => value == 'email' ? 'E-posta' : 'SMS';
  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';

  @override
  void dispose() {
    _voiceConfirmation.clear();
    _accessibility.finishSpeechInput();
    _stt.cancelListening();
    _noteController.dispose();
    super.dispose();
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Seçim', 'Önizleme', 'Onay', 'Sonuç'];
    return Semantics(
      label: 'Adım ${step + 1} / 4: ${labels[step]}',
      child: LinearProgressIndicator(value: (step + 1) / 4),
    );
  }
}
