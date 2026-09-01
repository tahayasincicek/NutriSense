import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/widgets/accessible_button.dart';
import 'privacy_consent_screen.dart';
import '../../../shared/widgets/auth_mode_switch.dart';
import '../state/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;

  static bool _isValidPassword(String value) =>
      value.length >= 8 &&
      RegExp('[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(value) &&
      RegExp('[0-9]').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -50,
            left: -50,
            child: CircleAvatar(
                radius: 120,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.08)),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                      side: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.2)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('Yeni Hesap',
                      style: theme.textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  Text('Sağlıklı yaşam yolculuğuna başla.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 28),

                  // Giriş ekranıyla aynı denetim; seçili segment bulunduğun
                  // ekranı gösterir.
                  AuthModeSwitch(
                    registering: true,
                    enabled: !_loading,
                    loginSemanticLabel: 'Giriş ekranına dönmek için basın',
                    onChanged: (registering) {
                      if (registering) return;
                      Navigator.pop(context);
                    },
                  ),

                  const SizedBox(height: 28),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Semantics(
                          label: 'Ad soyad giriş alanı',
                          textField: true,
                          child: TextFormField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Ad Soyad',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) => (v?.trim().length ?? 0) < 2
                                ? 'Geçerli bir ad soyad girin'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'E-posta adresi giriş alanı',
                          textField: true,
                          child: TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'E-posta',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Geçerli bir e-posta girin'
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'Şifre giriş alanı. '
                              'En az 8 karakter, harf ve rakam içermeli',
                          textField: true,
                          obscured: true,
                          child: TextFormField(
                            controller: _password,
                            obscureText: true,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: const InputDecoration(
                              labelText: 'Şifre',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                              helperText:
                                  'En az 8 karakter, harf ve rakam içermeli',
                              helperMaxLines: 2,
                            ),
                            validator: (v) => _isValidPassword(v ?? '')
                                ? null
                                : 'Şifre kriterlere uymuyor',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'Şifre tekrar giriş alanı',
                          textField: true,
                          obscured: true,
                          child: TextFormField(
                            controller: _confirmation,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Şifre Tekrar',
                              prefixIcon: Icon(Icons.lock_reset_rounded),
                            ),
                            validator: (v) => v == _password.text
                                ? null
                                : 'Şifreler eşleşmiyor',
                          ),
                        ),
                        const SizedBox(height: 32),
                        AccessibleButton(
                          label: 'Hesap Oluştur',
                          semanticLabel:
                              'Yeni hesabınızı oluşturmak için basın',
                          isLoading: _loading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await ref.read(authControllerProvider.notifier).register(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (error == null) {
      AccessibilityUtils.announceSuccess('Kayıt başarılı');
      // Aydınlatma ve açık rıza, veri işlenmeye başlamadan önce sunulur.
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PrivacyConsentScreen()),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
