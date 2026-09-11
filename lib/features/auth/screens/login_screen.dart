import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/auth_mode_switch.dart';
import '../state/auth_controller.dart';
import 'password_reset_screen.dart';
import 'register_screen.dart';
import '../../dietitian/screens/dietitian_access_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -100,
            right: -50,
            child: CircleAvatar(
                radius: 150,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1)),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
                radius: 100,
                backgroundColor:
                    AppTheme.secondaryColor.withValues(alpha: 0.05)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant_menu_rounded,
                          size: 64, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 24),
                    // Ekran okuyucuya sayfa başlığı olarak sunulur; VoiceOver
                    // ve TalkBack rotor'da başlıkla gezinmeyi sağlar.
                    Semantics(
                      header: true,
                      label: 'Giriş',
                      excludeSemantics: true,
                      child: Text('NutriSense',
                          style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryDark)),
                    ),
                    Text('Beslenmeni Akıllıca Yönet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),

                    const SizedBox(height: 32),

                    // Giriş / kayıt seçimi: diyetisyen ekranıyla aynı denetim.
                    AuthModeSwitch(
                      registering: false,
                      enabled: !_isLoading,
                      registerSemanticLabel:
                          'Yeni bir hesap oluşturmak için basın',
                      onChanged: (registering) {
                        if (!registering) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // Form Section
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Semantics(
                            label: 'E-posta adresi giriş alanı',
                            textField: true,
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'E-posta',
                                prefixIcon: Icon(Icons.email_outlined),
                                hintText: 'ornek@email.com',
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Geçerli bir e-posta girin'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Semantics(
                            label: 'Şifre giriş alanı',
                            textField: true,
                            obscured: _obscurePassword,
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  tooltip: _obscurePassword
                                      ? 'Şifreyi göster'
                                      : 'Şifreyi gizle',
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Şifre çok kısa'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Semantics(
                              button: true,
                              label: 'Şifremi unuttum. '
                                  'Parola sıfırlama ekranını açar',
                              excludeSemantics: true,
                              child: TextButton(
                                key: const Key('forgot_password'),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PasswordResetScreen(
                                      initialEmail:
                                          _emailController.text.trim(),
                                    ),
                                  ),
                                ),
                                child: const Text('Şifremi Unuttum'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          AccessibleButton(
                            label: 'Giriş Yap',
                            semanticLabel: 'Hesabınıza giriş yapmak için basın',
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'veya',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            button: true,
                            label: 'Diyetisyen giriş portalını aç',
                            child: OutlinedButton.icon(
                              key: const Key('dietitian_login'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const DietitianAccessScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.medical_services_outlined),
                              label: const Text('Diyetisyen Girişi'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Önceki hatadan kalan uyarı (SnackBar) mesajlarını temizliyoruz
    ScaffoldMessenger.of(context).clearSnackBars();

    // Olası odak ve klavye sorunlarını önlemek için klavyeyi kapatıyoruz
    FocusScope.of(context).unfocus();

    // Klavyenin ve snackbar'ın kapanması için widget ağacına minik bir zaman tanıyoruz
    // Bu, Scaffold unmount edilirken yaşanan "_dependents.isEmpty" crash'ini önler.
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    setState(() => _isLoading = true);

    final error = await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (error == null) {
      AccessibilityUtils.announceSuccess('Giriş başarılı');
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
