// =============================================================================
// lib/features/auth/screens/login_screen.dart
// NutriSense — Giriş Ekranı
//
// Erişilebilir giriş formu: büyük inputlar, semantik etiketler,
// sesli hata bildirimleri.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/accessible_text.dart';
import '../state/auth_controller.dart';
import 'register_screen.dart';

/// Giriş ekranı
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityUtils.announce(
        'NutriSense giriş ekranı. '
        'E-posta ve şifrenizi girerek devam edin.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Giriş',
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo ve Başlık ──
                    Semantics(
                      header: true,
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 72,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          AccessibleText(
                            'NutriSense',
                            style: theme.textTheme.displayMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                            semanticLabel: 'NutriSense uygulaması',
                            isHeader: true,
                          ),
                          const SizedBox(height: 8),
                          AccessibleText(
                            'Akıllı Besin Takibi',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                            semanticLabel: 'Akıllı besin takip uygulaması',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ── E-posta Alanı ──
                    Semantics(
                      label: 'E-posta adresi giriş alanı',
                      textField: true,
                      child: TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: theme.textTheme.bodyLarge,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          hintText: 'ornek@email.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 28),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'E-posta adresi gerekli';
                          }
                          if (!value.contains('@')) {
                            return 'Geçerli bir e-posta adresi girin';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_passwordFocus),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Şifre Alanı ──
                    Semantics(
                      label: 'Şifre giriş alanı',
                      textField: true,
                      child: TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          hintText: 'Şifrenizi girin',
                          prefixIcon: const Icon(Icons.lock_outlined, size: 28),
                          suffixIcon: Semantics(
                            label: _obscurePassword
                                ? 'Şifreyi göster'
                                : 'Şifreyi gizle',
                            button: true,
                            child: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 28,
                              ),
                              onPressed: () {
                                setState(
                                    () => _obscurePassword = !_obscurePassword);
                                AccessibilityUtils.announce(
                                  _obscurePassword
                                      ? 'Şifre gizlendi'
                                      : 'Şifre gösteriliyor',
                                );
                              },
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre gerekli';
                          }
                          if (value.length < 8) {
                            return 'Şifre en az 8 karakter olmalı';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _handleLogin(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Şifremi Unuttum ──
                    Align(
                      alignment: Alignment.centerRight,
                      child: AccessibleButton(
                        label: 'Şifremi Unuttum',
                        semanticLabel:
                            'Şifre sıfırlama sayfasına gitmek için dokunun',
                        type: AccessibleButtonType.text,
                        fullWidth: false,
                        onPressed: _showPasswordResetUnavailable,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Giriş Butonu ──
                    AccessibleButton(
                      label: 'Giriş Yap',
                      semanticLabel: 'Hesabınıza giriş yapmak için basın',
                      icon: Icons.login,
                      isLoading: _isLoading,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 16),

                    // ── Kayıt Ol ──
                    AccessibleButton(
                      label: 'Hesap Oluştur',
                      semanticLabel: 'Yeni bir hesap oluşturmak için basın',
                      icon: Icons.person_add_outlined,
                      type: AccessibleButtonType.outlined,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(name: '/register'),
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      AccessibilityUtils.announceError(
        'Form hatası var. Lütfen bilgilerinizi kontrol edin.',
      );
      await AccessibilityUtils.errorHaptic();
      return;
    }

    setState(() => _isLoading = true);
    AccessibilityUtils.announce('Giriş yapılıyor, lütfen bekleyin.');

    final error = await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      await AccessibilityUtils.successHaptic();
      AccessibilityUtils.announceSuccess('Giriş başarılı.');
    } else {
      await AccessibilityUtils.errorHaptic();
      if (!mounted) return;
      AccessibilityUtils.announceError(
        error,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _showPasswordResetUnavailable() async {
    AccessibilityUtils.announce(
      'Şifre sıfırlama henüz kullanılamıyor. Destek ekibiyle iletişime geçin.',
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifre Sıfırlama'),
        content: const Text(
          'Şifre sıfırlama henüz kullanılamıyor. Bu özellik etkinleşene kadar '
          'destek ekibiyle iletişime geçin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }
}
