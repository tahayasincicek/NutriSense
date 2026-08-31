import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/widgets/accessible_button.dart';
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
      appBar: AppBar(title: const Text('Diyetisyen Portalı')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medical_information_outlined,
                        size: 44,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      header: true,
                      child: Text(
                        _registering
                            ? 'Diyetisyen hesabı oluştur'
                            : 'Diyetisyen girişi',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Danışanlarınızı ve paylaşılan beslenme kayıtlarını '
                      'tek ekrandan takip edin.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Giriş'),
                          icon: Icon(Icons.login),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Kayıt'),
                          icon: Icon(Icons.person_add_alt_1),
                        ),
                      ],
                      selected: {_registering},
                      onSelectionChanged: _loading
                          ? null
                          : (selection) => setState(
                                () => _registering = selection.first,
                              ),
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
                        validator: (value) => (value?.trim().length ?? 0) < 2
                            ? 'Ad soyad gereklidir'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _specializationController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Uzmanlık alanı',
                          prefixIcon: Icon(Icons.workspace_premium_outlined),
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 2
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
                      validator: (value) => value?.contains('@') == true
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
                            () => _obscurePassword = !_obscurePassword,
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
                      isLoading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Hasta girişine dön'),
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

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final controller = ref.read(authControllerProvider.notifier);
    final String? error;
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
    if (!mounted) return;
    if (error != null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      AccessibilityUtils.announceError(error);
    } else {
      AccessibilityUtils.announceSuccess('Diyetisyen paneli açıldı');
    }
  }
}
