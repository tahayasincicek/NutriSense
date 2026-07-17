import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../state/auth_controller.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    switch (auth.status) {
      case AuthStatus.authenticated:
        return const AppShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.locked:
        return Scaffold(
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
      case AuthStatus.unknown:
      case AuthStatus.loading:
        return Scaffold(
          body: Center(
            child: Semantics(
              liveRegion: true,
              label: 'Güvenli oturum doğrulanıyor',
              child: const CircularProgressIndicator(),
            ),
          ),
        );
    }
  }
}
