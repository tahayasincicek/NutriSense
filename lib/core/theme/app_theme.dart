// =============================================================================
// lib/core/theme/app_theme.dart
// NutriSense — WCAG 2.1 AA Uyumlu Tema Sistemi
//
// Yüksek kontrast renk paleti, büyük font boyutları, erişilebilir bileşen
// stilleri. Karanlık ve aydınlık mod desteği.
// Kontrast oranları: Metin ≥ 4.5:1, Büyük metin ≥ 3:1, UI bileşenleri ≥ 3:1
// =============================================================================

import 'package:flutter/material.dart';

/// Ana tema sınıfı — Aydınlık ve karanlık tema tanımları
class AppTheme {
  AppTheme._(); // Singleton, instance oluşturulmasın

  // ---------------------------------------------------------------------------
  // RENK PALETİ — WCAG AA Uyumlu Yüksek Kontrast
  // ---------------------------------------------------------------------------

  // ── Ana Renkler (Primary) ──
  /// Koyu mavi — güven ve erişilebilirlik hissi verir
  static const Color primaryColor = Color(0xFF1565C0); // Blue 800
  static const Color primaryLight = Color(0xFF1E88E5); // Blue 600
  static const Color primaryDark = Color(0xFF0D47A1); // Blue 900

  // ── Vurgu Renkleri (Accent) ──
  /// Turuncu — dikkat çekici, besin/kalori temasına uygun
  static const Color accentColor = Color(0xFFE65100); // Orange 900
  static const Color accentLight = Color(0xFFF57C00); // Orange 800

  // ── Anlamsal Renkler (Semantic) ──
  static const Color successColor = Color(0xFF2E7D32); // Green 800
  static const Color warningColor = Color(0xFFE65100); // Orange 900
  static const Color errorColor = Color(0xFFC62828); // Red 800
  static const Color infoColor = Color(0xFF1565C0); // Blue 800

  // ── Yüzey Renkleri ──
  static const Color lightBackground = Color(0xFFFAFAFA); // Grey 50
  static const Color lightSurface = Color(0xFFFFFFFF); // White
  static const Color lightOnSurface = Color(0xFF1A1A1A); // Neredeyse siyah
  static const Color lightOnSurfaceVariant = Color(0xFF3D3D3D);

  static const Color darkBackground = Color(0xFF121212); // Material dark bg
  static const Color darkSurface = Color(0xFF1E1E1E); // Koyu yüzey
  static const Color darkOnSurface = Color(0xFFF5F5F5); // Neredeyse beyaz
  static const Color darkOnSurfaceVariant = Color(0xFFBDBDBD);

  // ---------------------------------------------------------------------------
  // TİPOGRAFİ — Büyük, Okunabilir Font Boyutları
  // ---------------------------------------------------------------------------

  /// Minimum body: 18sp, başlıklar: 24sp+
  /// Inter fontu kullanılır — yüksek x-height, okunabilir
  static TextTheme _buildTextTheme(Color textColor, Color secondaryTextColor) {
    return TextTheme(
      // Büyük başlık — ekran başlıkları
      displayLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -0.5,
        height: 1.3,
      ),
      // Orta başlık — bölüm başlıkları
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: textColor,
        letterSpacing: -0.25,
        height: 1.3,
      ),
      // Küçük başlık
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.3,
      ),
      // Sayfa başlığı
      headlineLarge: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.3,
      ),
      // Başlık — kartlar, list tile'lar
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: textColor,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textColor,
        height: 1.4,
      ),
      // Gövde metni — minimum 18sp
      bodyLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.6,
      ),
      bodySmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: secondaryTextColor,
        height: 1.5,
      ),
      // Etiket — buton, chip, badge
      labelLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0.5,
        height: 1.4,
      ),
      labelMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textColor,
        letterSpacing: 0.4,
        height: 1.4,
      ),
      labelSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
        letterSpacing: 0.4,
        height: 1.4,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUTON STİLLERİ — Büyük dokunma alanı (min 48×48dp)
  // ---------------------------------------------------------------------------

  static ButtonStyle _elevatedButtonStyle(Color bg, Color fg) {
    return ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      minimumSize: const Size(double.infinity, 56), // Yüksek dokunma alanı
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      textStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      elevation: 2,
    );
  }

  static ButtonStyle _outlinedButtonStyle(Color borderColor, Color fg) {
    return OutlinedButton.styleFrom(
      foregroundColor: fg,
      minimumSize: const Size(double.infinity, 56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      side: BorderSide(color: borderColor, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      textStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static ButtonStyle _textButtonStyle(Color fg) {
    return TextButton.styleFrom(
      foregroundColor: fg,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INPUT STİLLERİ — Erişilebilir form alanları
  // ---------------------------------------------------------------------------

  static InputDecorationTheme _inputTheme({
    required Color fillColor,
    required Color borderColor,
    required Color focusedBorderColor,
    required Color errorColor,
    required Color textColor,
    required Color hintColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      // Kalın kenarlık — görünürlüğü artırır
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focusedBorderColor, width: 3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor, width: 3),
      ),
      labelStyle: TextStyle(fontSize: 18, color: textColor),
      hintStyle: TextStyle(fontSize: 16, color: hintColor),
      errorStyle: TextStyle(fontSize: 14, color: errorColor),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
  }

  // ---------------------------------------------------------------------------
  // CARD STİLLERİ
  // ---------------------------------------------------------------------------

  static CardThemeData _cardTheme({
    required Color color,
    required Color shadowColor,
  }) {
    return CardThemeData(
      color: color,
      shadowColor: shadowColor,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: shadowColor.withOpacity(0.1)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AYDINLIK TEMA (Light Theme)
  // ---------------------------------------------------------------------------

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme(lightOnSurface, lightOnSurfaceVariant);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Renkler
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFBBDEFB),
        secondary: accentColor,
        onSecondary: Colors.white,
        surface: lightSurface,
        onSurface: lightOnSurface,
        error: errorColor,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: lightBackground,

      // Tipografi
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
      ),

      // Butonlar
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _elevatedButtonStyle(primaryColor, Colors.white),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButtonStyle(primaryColor, primaryColor),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _textButtonStyle(primaryColor),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        extendedPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        largeSizeConstraints: BoxConstraints.tightFor(width: 72, height: 72),
      ),

      // Input
      inputDecorationTheme: _inputTheme(
        fillColor: Colors.white,
        borderColor: const Color(0xFF757575),
        focusedBorderColor: primaryColor,
        errorColor: errorColor,
        textColor: lightOnSurface,
        hintColor: lightOnSurfaceVariant,
      ),

      // Card
      cardTheme: _cardTheme(
        color: lightSurface,
        shadowColor: Colors.black26,
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: const Color(0xFF757575),
        selectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
        selectedIconTheme: const IconThemeData(size: 30),
        unselectedIconTheme: const IconThemeData(size: 26),
        elevation: 8,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFFBDBDBD),
        thickness: 1,
        space: 24,
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: lightOnSurface,
        size: 28,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightOnSurface,
        contentTextStyle: TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: lightOnSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 18,
          color: lightOnSurface,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KARANLIK TEMA (Dark Theme)
  // ---------------------------------------------------------------------------

  static ThemeData get darkTheme {
    final textTheme = _buildTextTheme(darkOnSurface, darkOnSurfaceVariant);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Renkler
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        onPrimary: Color(0xFF0D47A1),
        primaryContainer: Color(0xFF1565C0),
        secondary: accentLight,
        onSecondary: Colors.black,
        surface: darkSurface,
        onSurface: darkOnSurface,
        error: Color(0xFFEF5350),
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: darkBackground,

      // Tipografi
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkOnSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: darkOnSurface,
        ),
        iconTheme: const IconThemeData(color: darkOnSurface, size: 28),
      ),

      // Butonlar
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _elevatedButtonStyle(primaryLight, Colors.white),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _outlinedButtonStyle(primaryLight, primaryLight),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _textButtonStyle(primaryLight),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        extendedPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        largeSizeConstraints: BoxConstraints.tightFor(width: 72, height: 72),
      ),

      // Input
      inputDecorationTheme: _inputTheme(
        fillColor: const Color(0xFF2C2C2C),
        borderColor: const Color(0xFF9E9E9E),
        focusedBorderColor: primaryLight,
        errorColor: const Color(0xFFEF5350),
        textColor: darkOnSurface,
        hintColor: darkOnSurfaceVariant,
      ),

      // Card
      cardTheme: _cardTheme(
        color: darkSurface,
        shadowColor: Colors.black54,
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryLight,
        unselectedItemColor: const Color(0xFF9E9E9E),
        selectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
        selectedIconTheme: const IconThemeData(size: 30),
        unselectedIconTheme: const IconThemeData(size: 26),
        elevation: 8,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFF424242),
        thickness: 1,
        space: 24,
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: darkOnSurface,
        size: 28,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkOnSurface,
        contentTextStyle: TextStyle(
          fontSize: 16,
          color: darkBackground,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: darkSurface,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: darkOnSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 18,
          color: darkOnSurface,
        ),
      ),
    );
  }
}
