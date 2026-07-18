// =============================================================================
// lib/main.dart
// NutriSense — Uygulama Giriş Noktası
//
// Riverpod ProviderScope, TTS başlatma, tema konfigürasyonu,
// erişilebilirlik ayarlarını içerir.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'shared/services/accessibility_service.dart';
import 'app.dart';
import 'features/auth/screens/auth_gate.dart';

void main() async {
  // Flutter engine başlatma — native platform çağrıları için gerekli
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  // Durum çubuğu stili
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Uygulamayı Riverpod ProviderScope içinde başlat
  runApp(
    const ProviderScope(
      child: NutriSenseApp(),
    ),
  );
}

/// Ana uygulama widget'ı
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
    // TTS motorunu başlat
    if (widget.initializePlatformServices) {
      _initializeServices();
    }
  }

  Future<void> _initializeServices() async {
    // TTS servisini asenkron olarak başlat
    final accessibility = ref.read(accessibilityServiceProvider);
    await accessibility.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Uygulama bilgileri
      title: 'NutriSense',
      debugShowCheckedModeBanner: false,

      // ── Tema Yapılandırması ──
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Sistem temasına uy

      // ── Erişilebilirlik ──
      // showSemanticsDebugger: true, // DEBUG: Semantik ağacı görselleştir

      // ── Lokalizasyon ──
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

      // ── Ana Sayfa ──
      home: widget.bypassAuthenticationForTests
          ? const AppShell()
          : const AuthGate(),

      // ── Navigasyon Geçiş Animasyonu ──
      builder: (context, child) {
        // Erişilebilirlik: Sistem font ölçeklendirmesine saygı göster
        // ama minimum boyutu garanti et. (Flutter TextScaler.clamp bug'ını
        // önlemek için _CustomTextScaler kullanarak sınırlandırıyoruz)
        final mediaQuery = MediaQuery.of(context);
        final double scaleFactor = mediaQuery.textScaler.scale(10.0) / 10.0;
        final customScaler = TextScaler.linear(scaleFactor.clamp(1.0, 2.0));

        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: customScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
