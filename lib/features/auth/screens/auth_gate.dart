import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../state/auth_controller.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    
    Widget currentWidget;
    switch (auth.status) {
      case AuthStatus.authenticated:
        currentWidget = const _OnboardingGate();
        break;
      case AuthStatus.unauthenticated:
        currentWidget = const LoginScreen();
        break;
      case AuthStatus.locked:
        currentWidget = Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_clock_outlined, size: 64),
                    const SizedBox(height: 20),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        auth.message ?? 'Oturum kilitlendi.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AccessibleButton(
                      label: 'Yeniden Giriş Yap',
                      onPressed: () => ref
                          .read(authControllerProvider.notifier)
                          .unlockToLogin(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        break;
      case AuthStatus.unknown:
      case AuthStatus.loading:
      default:
        currentWidget = Scaffold(
          body: Center(
            child: Semantics(
              liveRegion: true,
              label: 'Güvenli oturum doğrulanıyor',
              child: const CircularProgressIndicator(),
            ),
          ),
        );
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(auth.status),
        child: currentWidget,
      ),
    );
  }
}

/// Onboarding tamamlanmamışsa onboarding ekranını göster
class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final done = await isOnboardingComplete();
    if (mounted) setState(() => _onboardingDone = done);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_onboardingDone == false) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboardingDone = true),
      );
    }
    return const AppShell();
  }
}
