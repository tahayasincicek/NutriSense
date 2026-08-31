// =============================================================================
// lib/features/auth/screens/password_reset_screen.dart
// NutriSense — Parola sıfırlama
//
// İki adımlı akış tek ekranda yürür: önce e-posta ile kod istenir, sonra kod
// ve yeni parola girilir. Her adım geçişi ekran okuyucuya duyurulur; kod
// alanı sesle de doldurulabilir (8 haneli sayı, Türkçe sayı ayrıştırıcı ile).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/stt_service.dart';
import '../../../shared/services/turkish_number_parser.dart';
import '../../../shared/widgets/accessible_button.dart';

enum _ResetStep { requestCode, enterCode }

class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();

  late final AccessibilityService _accessibility;
  late final SttService _stt;

  _ResetStep _step = _ResetStep.requestCode;
  bool _busy = false;
  bool _obscure = true;
  bool _listening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _stt = ref.read(sttServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibility.speak(
        'Parola sıfırlama ekranı. E-posta adresinizi girin, '
        'size sekiz haneli bir kod göndereceğiz.',
        priority: TtsPriority.high,
      );
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Geçerli bir e-posta adresi girin.');
      _accessibility.speakError('Geçerli bir e-posta adresi girin.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await ref.read(apiServiceProvider).requestPasswordReset(email: email);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.isSuccess) {
      final message = result.errorMessage ?? 'Kod gönderilemedi.';
      setState(() => _error = message);
      _accessibility.speakError(message);
      return;
    }

    setState(() => _step = _ResetStep.enterCode);
    await AccessibilityUtils.successHaptic();
    _accessibility.speak(
      '${result.data} '
      'Şimdi sekiz haneli kodu ve yeni parolanızı girin. '
      'Kodu yazabilir ya da söyleyebilirsiniz.',
      priority: TtsPriority.high,
    );
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
        // Önce düz rakamları topla ("dokuz beş dört..." ya da "95422979").
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
        setState(() => _error = 'Kod anlaşılamadı. Tekrar söyleyin.');
        _accessibility.speakError(
          'Kod anlaşılamadı. Rakamları tek tek söyleyebilirsiniz.',
        );
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
    final password = _password.text;

    if (code.length < 8) {
      setState(() => _error = 'Sekiz haneli kodu girin.');
      _accessibility.speakError('Sekiz haneli kodu girin.');
      return;
    }
    if (password.length < 8 ||
        !password.contains(RegExp(r'[A-Za-zçğıöşüÇĞİÖŞÜ]')) ||
        !password.contains(RegExp(r'[0-9]'))) {
      const message =
          'Parola en az 8 karakter olmalı, harf ve rakam içermelidir.';
      setState(() => _error = message);
      _accessibility.speakError(message);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(apiServiceProvider).confirmPasswordReset(
          token: code,
          newPassword: password,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.isSuccess) {
      final message = result.errorMessage ?? 'Parola güncellenemedi.';
      setState(() => _error = message);
      _accessibility.speakError(message);
      return;
    }

    await AccessibilityUtils.successHaptic();
    _accessibility.speak(
      '${result.data} Giriş ekranına dönülüyor.',
      priority: TtsPriority.high,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onCodeStep = _step == _ResetStep.enterCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Parolamı Unuttum')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  onCodeStep ? 'Kodu girin' : 'E-posta adresiniz',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                onCodeStep
                    ? 'E-postanıza gönderilen sekiz haneli kodu ve yeni '
                        'parolanızı girin. Kod bir saat geçerlidir.'
                    : 'Kayıtlı e-posta adresinizi girin; size sekiz haneli '
                        'bir sıfırlama kodu göndereceğiz.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              Semantics(
                label: 'E-posta adresi giriş alanı',
                textField: true,
                child: TextField(
                  key: const Key('reset_email'),
                  controller: _email,
                  enabled: !onCodeStep && !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ),

              if (onCodeStep) ...[
                const SizedBox(height: 16),
                Semantics(
                  label: 'Sıfırlama kodu giriş alanı, sekiz haneli sayı',
                  textField: true,
                  child: TextField(
                    key: const Key('reset_code'),
                    controller: _code,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Sıfırlama kodu',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      helperText: 'E-postanıza gönderilen 8 haneli kod',
                      helperMaxLines: 2,
                      suffixIcon: IconButton(
                        key: const Key('reset_code_voice'),
                        icon: Icon(_listening
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded),
                        tooltip: 'Kodu sesle söyle',
                        onPressed: _listening || _busy ? null : _listenForCode,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Yeni parola giriş alanı. '
                      'En az 8 karakter, harf ve rakam içermeli',
                  textField: true,
                  obscured: _obscure,
                  child: TextField(
                    key: const Key('reset_password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Yeni parola',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      helperText: 'En az 8 karakter, harf ve rakam içermeli',
                      helperMaxLines: 2,
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility),
                        tooltip:
                            _obscure ? 'Parolayı göster' : 'Parolayı gizle',
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                          color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              AccessibleButton(
                key: const Key('reset_primary_action'),
                label: onCodeStep ? 'Parolayı Güncelle' : 'Kod Gönder',
                semanticLabel: onCodeStep
                    ? 'Yeni parolanızı kaydetmek için basın'
                    : 'Sıfırlama kodunu e-postanıza göndermek için basın',
                isLoading: _busy,
                onPressed: _busy ? null : (onCodeStep ? _confirm : _requestCode),
              ),

              if (onCodeStep) ...[
                const SizedBox(height: 12),
                AccessibleButton(
                  label: 'Kodu Yeniden Gönder',
                  semanticLabel: 'Yeni bir sıfırlama kodu istemek için basın',
                  type: AccessibleButtonType.text,
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() => _step = _ResetStep.requestCode);
                          _accessibility.speak(
                            'E-posta adımına dönüldü.',
                            priority: TtsPriority.high,
                          );
                        },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
