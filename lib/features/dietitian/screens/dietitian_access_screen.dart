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
  static const _agreementVersion = 'DIETITIAN-DPA-2026-01';
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _specializationController =
      TextEditingController(text: 'Beslenme ve Diyet');
  bool _registering = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _agreementAccepted = false;

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
                        'Diyetisyen Paneli',
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
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.11),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.medical_information_rounded,
                                    size: 44,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Semantics(
                                header: true,
                                child: Text(
                                  _registering
                                      ? 'Uzman hesabını oluştur'
                                      : 'Diyetisyen Portalı',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    color: AppTheme.primaryDark,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
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
                              if (_registering) ...[
                                const SizedBox(height: 16),
                                CheckboxListTile(
                                  key: const Key('dietitian_dpa_acceptance'),
                                  value: _agreementAccepted,
                                  onChanged: _loading
                                      ? null
                                      : (value) => setState(() =>
                                          _agreementAccepted = value ?? false),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Diyetisyen Gizlilik ve Veri İşleme '
                                    'Sözleşmesi’ni okudum ve kabul ediyorum.',
                                  ),
                                  subtitle: TextButton(
                                    key: const Key('dietitian_dpa_open'),
                                    onPressed: _showAgreement,
                                    child: const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Sözleşmeyi oku'),
                                    ),
                                  ),
                                ),
                              ],
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
    if (_registering && !_agreementAccepted) {
      const message =
          'Hesap oluşturmak için veri işleme sözleşmesini okuyup kabul edin.';
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(message)));
      AccessibilityUtils.announceError(message);
      return;
    }
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
          dataProcessingAgreementAccepted: _agreementAccepted,
          dataProcessingAgreementVersion: _agreementVersion,
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

  Future<void> _showAgreement() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diyetisyen Gizlilik ve Veri İşleme Sözleşmesi'),
        content: const SingleChildScrollView(
          child: Text(
            'Sürüm: DIETITIAN-DPA-2026-01\n\n'
            'Diyetisyen; yalnız kendisine atanmış danışanların verilerine, '
            'beslenme hizmetinin yürütülmesi amacıyla ve gerektiği ölçüde '
            'erişmeyi; verileri başka kişi veya amaçlarla paylaşmamayı; hesap '
            'bilgilerini korumayı; yetkisiz erişim veya veri ihlali şüphesini '
            'derhal NutriSense veri sorumlusuna bildirmeyi; ilişki sona '
            'erdiğinde erişimi bırakmayı ve yürürlükteki gizlilik, meslek sırrı '
            've kişisel veri kurallarına uymayı kabul eder.\n\n'
            'Bu elektronik kabul, kabul edilen metin sürümü ve zamanıyla '
            'kaydedilir. Veri sorumlusunun kimliği, iletişim adresi, saklama '
            'süreleri ve tarafların ayrıntılı yükümlülükleri yayımlanan nihai '
            'kurumsal sözleşmede ayrıca yer almalıdır.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
