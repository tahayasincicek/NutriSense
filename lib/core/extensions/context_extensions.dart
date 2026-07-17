// =============================================================================
// lib/core/extensions/context_extensions.dart
// NutriSense — BuildContext Extension Metotları
//
// Tema, renk, tipografi ve navigasyona kolay erişim için extension'lar.
// =============================================================================

import 'package:flutter/material.dart';

/// BuildContext üzerinde tema ve navigasyon kısayolları
extension ContextExtensions on BuildContext {
  // ── Tema ──
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  bool get isDarkMode => theme.brightness == Brightness.dark;

  // ── Ekran boyutları ──
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get padding => MediaQuery.paddingOf(this);
  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);

  // ── Erişilebilirlik ──
  bool get isBoldText => MediaQuery.boldTextOf(this);
  double get textScaleFactor => MediaQuery.textScaleFactorOf(this);
  bool get isReduceMotion => MediaQuery.disableAnimationsOf(this);
  bool get isHighContrast => MediaQuery.highContrastOf(this);

  // ── Navigasyon ──
  NavigatorState get navigator => Navigator.of(this);

  void pushScreen(Widget screen) {
    Navigator.of(this).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void pushReplacementScreen(Widget screen) {
    Navigator.of(this).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void pop<T>([T? result]) => Navigator.of(this).pop(result);

  // ── Snackbar ──
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor:
            isError ? colorScheme.error : colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
