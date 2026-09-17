import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../state/auth_controller.dart';

class EmailChangeScreen extends ConsumerStatefulWidget {
  const EmailChangeScreen({super.key});

  @override
  ConsumerState<EmailChangeScreen> createState() => _EmailChangeScreenState();
}

class _EmailChangeScreenState extends ConsumerState<EmailChangeScreen> {
  final _requestKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _codeRequested = false;
  bool _loading = false;
  String? _status;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_requestKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref.read(apiServiceProvider).requestEmailChange(
          newEmail: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = result.isSuccess
          ? result.data
          : result.errorMessage ?? 'İstek tamamlanamadı.';
      _codeRequested = result.isSuccess;
      if (result.isSuccess) _password.clear();
    });
    if (result.isSuccess) {
      AccessibilityUtils.announceSuccess(_status!);
    }
  }

  Future<void> _confirm() async {
    if (!RegExp(r'^\d{8}$').hasMatch(_code.text.trim())) {
      setState(() => _status = 'Sekiz haneli doğrulama kodunu girin.');
      return;
    }
    setState(() => _loading = true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .confirmEmailChange(_code.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      setState(() => _status = error);
      return;
    }
    AccessibilityUtils.announceSuccess('E-posta adresiniz değiştirildi.');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = ref.watch(authControllerProvider).user?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('E-postamı Değiştir')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Semantics(
            header: true,
            child: Text(
              _codeRequested
                  ? 'Yeni adresinizi doğrulayın'
                  : 'Yeni e-posta adresi',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _codeRequested
                ? 'Kod yalnız yeni e-posta adresine gönderildi. Kod '
                    'doğrulanana kadar mevcut adresiniz değişmez.'
                : 'Mevcut adres: $currentEmail. Güvenliğiniz için parolanız '
                    've yeni adrese gönderilen kod gereklidir.',
          ),
          const SizedBox(height: 24),
          if (!_codeRequested)
            Form(
              key: _requestKey,
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('email_change_new_email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Yeni e-posta',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (value) => value != null && value.contains('@')
                        ? null
                        : 'Geçerli bir e-posta girin',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('email_change_password'),
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Mevcut parola',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (value) => value?.isNotEmpty == true
                        ? null
                        : 'Mevcut parolanızı girin',
                  ),
                  const SizedBox(height: 24),
                  AccessibleButton(
                    key: const Key('email_change_request'),
                    label: 'Doğrulama Kodu Gönder',
                    isLoading: _loading,
                    onPressed: _requestCode,
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              key: const Key('email_change_code'),
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 8,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(
                labelText: 'Sekiz haneli doğrulama kodu',
                prefixIcon: Icon(Icons.verified_outlined),
              ),
            ),
            const SizedBox(height: 16),
            AccessibleButton(
              key: const Key('email_change_confirm'),
              label: 'E-posta Adresini Değiştir',
              isLoading: _loading,
              onPressed: _confirm,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                        _codeRequested = false;
                        _code.clear();
                        _status = null;
                      }),
              child: const Text('Farklı adres kullan'),
            ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text(
                _status!,
                key: const Key('email_change_status'),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
