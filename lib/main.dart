// =============================================================================
// lib/main.dart
// NutriSense — Uygulama Giriş Noktası (Modernized)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'shared/services/accessibility_service.dart';
import 'shared/services/speech_route_observer.dart';
import 'app.dart';
import 'features/auth/screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  // Sistem çubuğunu modern temaya uyumlu hale getir
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          Brightness.dark, // Açık renk arka plan için koyu ikonlar
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: NutriSenseApp(),
    ),
  );
}

class NutriSenseApp extends ConsumerStatefulWidget {
  const NutriSenseApp({
    super.key,
    this.initializePlatformServices = true,
    this.bypassAuthenticationForTests = false,
  });

  final bool initializePlatformServices;
  final bool bypassAuthenticationForTests;

  @override
  ConsumerState<NutriSenseApp> createState() => _NutriSenseAppState();
}

class _NutriSenseAppState extends ConsumerState<NutriSenseApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initializePlatformServices) {
      _initializeServices();
    }
  }

  Future<void> _initializeServices() async {
    final accessibility = ref.read(accessibilityServiceProvider);
    await accessibility.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriSense',
      debugShowCheckedModeBanner: false,

      // Ekran değişince önceki ekranın sesli anlatımı susar.
      navigatorObservers: [
        SpeechRouteObserver(ref.read(accessibilityServiceProvider)),
      ],

      // --- Yeni Premium Tema ---
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Kullanıcının Ayarlar'daki tercihi; kayıtlı değilse cihaz ayarı.
      themeMode: ref.watch(themeControllerProvider),

      // --- Lokalizasyon ---
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: widget.bypassAuthenticationForTests
          ? const AppShell()
          : const AuthGate(),

      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        // Erişilebilirlik ölçeklendirmesini korurken aşırı büyümeyi engelle
        final double scaleFactor = mediaQuery.textScaler.scale(10.0) / 10.0;
        final customScaler = TextScaler.linear(scaleFactor.clamp(1.0, 1.4));

        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: customScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
