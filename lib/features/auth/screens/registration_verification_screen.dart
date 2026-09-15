// =============================================================================
// lib/features/auth/screens/registration_verification_screen.dart
// NutriSense — Kayıt e-posta doğrulaması
//
// Kayıt formu gönderilince açılır. Sunucu, adres kayıtlı olsa da olmasa da
// aynı yanıtı verir; hesap yalnız e-postaya gelen sekiz haneli kod girilince
// açılır. Kod yazılabilir ya da sesle söylenebilir.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/stt_service.dart';
import '../../../shared/services/turkish_number_parser.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../state/auth_controller.dart';

class RegistrationVerificationScreen extends ConsumerStatefulWidget {
  const RegistrationVerificationScreen({
    super.key,
    required this.email,
    required this.onResend,
  });

  final String email;

  /// Kayıt isteğini aynı bilgilerle yeniden gönderir; hata varsa mesajını döner.
  final Future<String?> Function() onResend;

  @override
  ConsumerState<RegistrationVerificationScreen> createState() =>
      _RegistrationVerificationScreenState();
}

class _RegistrationVerificationScreenState
    extends ConsumerState<RegistrationVerificationScreen> {
  final _code = TextEditingController();

  late final AccessibilityService _accessibility;
  late final SttService _stt;

  bool _busy = false;
  bool _listening = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _stt = ref.read(sttServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibility.speak(
        'E-posta doğrulama ekranı. E-posta adresinize sekiz haneli bir kod '
        'gönderdik. Kodu yazabilir ya da söyleyebilirsiniz.',
        priority: TtsPriority.high,
      );
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _error = message;
      _info = null;
    });
    _accessibility.speakError(message);
  }

  /// Kodu sesle girme. 8 haneli sayı, rakam rakam da söylenebilir.
  Future<void> _listenForCode() async {
    setState(() => _listening = true);
    _accessibility.speak('Dinliyorum. Kodu söyleyin.',
        priority: TtsPriority.high);
    await _stt.startListening(
      onResult: (result) {
        if (!result.isFinal || !mounted) return;
        setState(() => _listening = false);
        final digits = result.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length == 8) {
          setState(() => _code.text = digits);
          _accessibility.speak('Kod girildi: $digits',
              priority: TtsPriority.high);
          return;
        }
        final parsed = parseTurkishNumber(result.text);
        if (parsed != null && parsed >= 0) {
          final text = parsed.toInt().toString().padLeft(8, '0');
          setState(() => _code.text = text);
          _accessibility.speak('Kod girildi: $text',
              priority: TtsPriority.high);
          return;
        }
        _showError('Kod anlaşılamadı. Rakamları tek tek söyleyebilirsiniz.');
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _listening = false);
        _accessibility.speakError(
          'Ses tanıma kullanılamıyor. Kodu yazarak girebilirsiniz.',
        );
      },
    );
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (code.length != 8) {
      _showError('Sekiz haneli kodu girin.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .confirmRegistration(email: widget.email, code: code);
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      _showError(error);
      return;
    }
    await AccessibilityUtils.successHaptic();
    AccessibilityUtils.announceSuccess('Hesabınız oluşturuldu');
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final error = await widget.onResend();
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      _showError(error);
      return;
    }
    const message = 'Yeni kod gönderildi. Önceki kod artık geçersiz.';
    setState(() {
      _code.clear();
      _info = message;
    });
    _accessibility.speak(message, priority: TtsPriority.high);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('E-postanı Doğrula')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('Kodu girin', style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.email} adresine sekiz haneli bir kod gönderdik. '
                'Kod 30 dakika geçerlidir. Gelen kutunuzda yoksa istenmeyen '
                'klasörüne bakın.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Semantics(
                label: 'Doğrulama kodu giriş alanı, sekiz haneli sayı',
                textField: true,
                child: TextField(
                  key: const Key('verification_code'),
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Doğrulama kodu',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    helperText: 'E-postanıza gönderilen 8 haneli kod',
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      key: const Key('verification_code_voice'),
                      icon: Icon(_listening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded),
                      tooltip: 'Kodu sesle söyle',
                      onPressed: _listening || _busy ? null : _listenForCode,
                    ),
                  ),
                ),
              ),
              if (_error != null || _info != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: Key(_error != null
                        ? 'verification_error'
                        : 'verification_info'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _error != null
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error ?? _info!,
                      style: TextStyle(
                        color: _error != null
                            ? theme.colorScheme.onErrorContainer
                            : theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AccessibleButton(
                key: const Key('verification_confirm'),
                label: 'Hesabı Oluştur',
                semanticLabel:
                    'Kodu doğrulayıp hesabınızı oluşturmak için basın',
                isLoading: _busy,
                onPressed: _busy ? null : _confirm,
              ),
              const SizedBox(height: 12),
              AccessibleButton(
                key: const Key('verification_resend'),
                label: 'Kodu Yeniden Gönder',
                semanticLabel: 'Yeni bir doğrulama kodu istemek için basın',
                type: AccessibleButtonType.text,
                onPressed: _busy ? null : _resend,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
