// =============================================================================
// lib/shared/widgets/accessible_number_dialog.dart
// NutriSense — Klavyesiz sayı girişi
//
// Tam görme kaybı olan kullanıcı için sayı girmenin üç yolu vardır ve hiçbiri
// diğerine bağımlı değildir:
//   1. Konuşarak     — "yedi buçuk" (klavye hiç gerekmez)
//   2. Artır/azalt   — dokunarak; STT çalışmasa bile kullanılabilir
//   3. Klavyeyle     — gören kullanıcılar için korunur
//
// Uygulamadaki her sayısal giriş bu diyaloğu kullanır; böylece davranış
// her yerde aynıdır ve bir ekranda düzeltilen sorun hepsinde düzelir.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/accessibility_service.dart';
import '../services/stt_service.dart';
import '../services/turkish_number_parser.dart';

/// Klavye gerektirmeyen sayı giriş diyaloğu.
///
/// Kullanımı:
/// ```dart
/// final value = await showAccessibleNumberDialog(
///   context: context,
///   title: 'Uyku Süresi',
///   fieldLabel: 'Uyku süresi',
///   suffix: 'saat',
///   spokenUnit: 'saat',
///   min: 0, max: 24, step: 0.5,
/// );
/// ```
Future<double?> showAccessibleNumberDialog({
  required BuildContext context,
  required String title,
  required String fieldLabel,
  required String suffix,
  required String spokenUnit,
  required double min,
  required double max,
  required double step,
  String? helper,
  String? semanticLabel,
  double? initialValue,
  Key? fieldKey,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => AccessibleNumberDialog(
      title: title,
      fieldLabel: fieldLabel,
      suffix: suffix,
      spokenUnit: spokenUnit,
      min: min,
      max: max,
      step: step,
      helper: helper ??
          '${speakableNumber(min)} ile ${speakableNumber(max)} '
              '$spokenUnit arasında olmalıdır.',
      semanticLabel: semanticLabel ?? '$fieldLabel giriş alanı, $spokenUnit',
      initialValue: initialValue,
      fieldKey: fieldKey ?? const Key('number_input_field'),
    ),
  );
}

class AccessibleNumberDialog extends ConsumerStatefulWidget {
  const AccessibleNumberDialog({
    super.key,
    required this.title,
    required this.fieldLabel,
    required this.suffix,
    required this.spokenUnit,
    required this.helper,
    required this.semanticLabel,
    required this.min,
    required this.max,
    required this.step,
    required this.fieldKey,
    this.initialValue,
  });

  final String title;
  final String fieldLabel;
  final String suffix;

  /// Sesli duyuruda kullanılan birim ("saat", "kilogram", "kalori").
  final String spokenUnit;
  final String helper;
  final String semanticLabel;
  final double min;
  final double max;

  /// Artır/azalt düğmelerinin adım büyüklüğü.
  final double step;
  final Key fieldKey;
  final double? initialValue;

  @override
  ConsumerState<AccessibleNumberDialog> createState() =>
      _AccessibleNumberDialogState();
}

class _AccessibleNumberDialogState
    extends ConsumerState<AccessibleNumberDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue == null
        ? ''
        : speakableNumber(widget.initialValue!),
  );
  late final AccessibilityService _accessibility =
      ref.read(accessibilityServiceProvider);
  late final SttService _stt = ref.read(sttServiceProvider);

  String? _error;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openWithVoice());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _currentValue =>
      double.tryParse(_controller.text.trim().replaceAll(',', '.'));

  void _setValue(double value, {bool announce = true}) {
    final clamped = value.clamp(widget.min, widget.max);
    setState(() {
      _controller.text = speakableNumber(clamped);
      _error = null;
    });
    if (announce) {
      _accessibility.speak(
        '${speakableNumber(clamped)} ${widget.spokenUnit}',
        priority: TtsPriority.high,
      );
    }
  }

  void _nudge(double delta) {
    final base = _currentValue ?? widget.initialValue ?? widget.min;
    _setValue(base + delta);
  }

  /// Sesle değer girme. STT yoksa diğer iki yol çalışmaya devam eder.
  /// Diyalog açılır açılmaz dinlemeye geçer.
  ///
  /// Görme engelli kullanıcıya "mikrofon düğmesine basın" demek, göremediği
  /// bir düğmeyi aramasını istemektir. Bunun yerine mikrofon kendiliğinden
  /// açılır; kullanıcı yalnız değeri söyler.
  ///
  /// Ekran okuyucu açıkken otomatik dinleme yapılmaz: TalkBack alanı kendisi
  /// seslendirir ve kullanıcının kendi akışı vardır, mikrofonu habersiz
  /// açmak onu keser.
  Future<void> _openWithVoice() async {
    final screenReader = _accessibility.screenReaderActive;
    await _accessibility.speak(
      screenReader
          ? '${widget.title}. ${widget.helper}'
          : '${widget.title}. ${widget.helper} Değeri söyleyin.',
      priority: TtsPriority.high,
    );
    if (!mounted || screenReader) return;
    await _listen();
  }

  Future<void> _listen() async {
    setState(() => _listening = true);
    _accessibility.speak('Dinliyorum. Değeri söyleyin.',
        priority: TtsPriority.high);
    await _stt.startListening(
      onResult: (result) {
        if (!result.isFinal || !mounted) return;
        setState(() => _listening = false);
        final parsed = parseTurkishNumber(result.text);
        if (parsed == null) {
          setState(() => _error = 'Anlaşılamadı. Tekrar söyleyin.');
          _accessibility.speakError(
            'Sayı anlaşılamadı. Tekrar söyleyin ya da '
            'artır azalt düğmelerini kullanın.',
          );
          return;
        }
        if (parsed < widget.min || parsed > widget.max) {
          setState(() => _error = widget.helper);
          _accessibility.speakError(widget.helper);
          return;
        }
        _setValue(parsed);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _listening = false);
        _accessibility.speakError(
          'Ses tanıma kullanılamıyor. Artır ve azalt düğmelerini '
          'kullanabilirsiniz.',
        );
      },
    );
  }

  void _submit() {
    final parsed = _currentValue;
    if (parsed == null || !parsed.isFinite) {
      setState(() => _error = 'Lütfen bir değer girin.');
      _accessibility.speakError('Lütfen bir değer girin.');
      return;
    }
    if (parsed < widget.min || parsed > widget.max) {
      setState(() => _error = widget.helper);
      _accessibility.speakError(widget.helper);
      return;
    }
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    final display = _currentValue;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: widget.semanticLabel,
              textField: true,
              value: display == null
                  ? 'boş'
                  : '${speakableNumber(display)} ${widget.spokenUnit}',
              child: TextField(
                key: widget.fieldKey,
                controller: _controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: widget.fieldLabel,
                  suffixText: widget.suffix,
                  helperText: widget.helper,
                  helperMaxLines: 3,
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Dokunarak değer değiştirme: klavye gerektirmez, her adımda
            // yeni değer sesli duyurulur.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  key: const Key('number_input_decrease'),
                  icon: const Icon(Icons.remove_rounded),
                  tooltip: '${speakableNumber(widget.step)} azalt',
                  onPressed: () => _nudge(-widget.step),
                ),
                IconButton.filledTonal(
                  key: const Key('number_input_voice'),
                  icon: Icon(
                      _listening ? Icons.mic_rounded : Icons.mic_none_rounded),
                  tooltip: 'Değeri sesle söyle',
                  onPressed: _listening ? null : _listen,
                ),
                IconButton.filledTonal(
                  key: const Key('number_input_increase'),
                  icon: const Icon(Icons.add_rounded),
                  tooltip: '${speakableNumber(widget.step)} artır',
                  onPressed: () => _nudge(widget.step),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          key: const Key('number_input_save'),
          onPressed: _submit,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
