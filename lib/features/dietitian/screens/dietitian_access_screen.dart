import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../../shared/widgets/auth_mode_switch.dart';
import '../../auth/state/auth_controller.dart';

class DietitianAccessScreen extends ConsumerStatefulWidget {
  const DietitianAccessScreen({super.key});

  @override
  ConsumerState<DietitianAccessScreen> createState() =>
      _DietitianAccessScreenState();
}

class _DietitianAccessScreenState extends ConsumerState<DietitianAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _specializationController =
      TextEditingController(text: 'Beslenme ve Diyet');
  bool _registering = false;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -85,
            child: CircleAvatar(
              radius: 190,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.09),
            ),
          ),
          Positioned(
            top: 115,
            right: 26,
            child: CircleAvatar(
              radius: 68,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.09),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.05),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Hasta girişine dön',
                        onPressed:
                            _loading ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.eco_rounded,
                        size: 20,
                        color: AppTheme.primaryDark,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'NutriSense Pro',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.medical_information_rounded,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      'PROFESYONEL PORTAL',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: AppTheme.primaryDark,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Semantics(
                                header: true,
                                child: Text(
                                  _registering
                                      ? 'Uzman Hesabı Oluştur'
                                      : 'Diyetisyen Girişi',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                _registering
                                    ? 'NutriSense ile danışanlarını tek ve güvenli bir yerden takip etmeye başla.'
                                    : 'Danışanlarını ve paylaşılan beslenme kayıtlarını tek ekrandan takip et.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 28),
                              AuthModeSwitch(
                                registering: _registering,
                                enabled: !_loading,
                                onChanged: (value) =>
                                    setState(() => _registering = value),
                              ),
                              const SizedBox(height: 24),
                              if (_registering) ...[
                                TextFormField(
                                  controller: _nameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Ad soyad',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (value) =>
                                      (value?.trim().length ?? 0) < 2
                                          ? 'Ad soyad gereklidir'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _specializationController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Uzmanlık alanı',
                                    prefixIcon: Icon(
                                      Icons.workspace_premium_outlined,
                                    ),
                                  ),
                                  validator: (value) =>
                                      (value?.trim().length ?? 0) < 2
                                          ? 'Uzmanlık alanı gereklidir'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                              ],
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'Mesleki e-posta',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (value) =>
                                    value?.contains('@') == true
                                        ? null
                                        : 'Geçerli bir e-posta girin',
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Şifre',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Şifreyi göster'
                                        : 'Şifreyi gizle',
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                                validator: (value) => (value?.length ?? 0) < 8
                                    ? 'Şifre en az 8 karakter olmalıdır'
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              AccessibleButton(
                                label: _registering
                                    ? 'Diyetisyen Hesabı Oluştur'
                                    : 'Panele Giriş Yap',
                                icon: _registering
                                    ? Icons.person_add_alt_1_rounded
                                    : Icons.login_rounded,
                                isLoading: _loading,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 16),
                              AccessibleButton(
                                label: 'Hasta Girişine Dön',
                                icon: Icons.person_outline_rounded,
                                type: AccessibleButtonType.outlined,
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final controller = ref.read(authControllerProvider.notifier);
    String? error;
    try {
      if (_registering) {
        error = await controller.registerDietitian(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          specialization: _specializationController.text.trim(),
        );
      } else {
        error = await controller.loginDietitian(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on TimeoutException {
      error = 'Giriş isteği zaman aşımına uğradı. Lütfen tekrar deneyin.';
    } catch (_) {
      error = 'Giriş sırasında beklenmeyen bir hata oluştu. Tekrar deneyin.';
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      AccessibilityUtils.announceError(error);
    } else {
      AccessibilityUtils.announceSuccess('Diyetisyen paneli açıldı');
      // Bu ekran giriş sayfasının üstüne push edildiği için AuthGate altta
      // paneli hazırlasa bile görünür kalıyordu. Başarılı girişte portal
      // rotasını kapatıp alttaki diyetisyen panelini hemen göster.
      Navigator.of(context).pop();
    }
  }
}
