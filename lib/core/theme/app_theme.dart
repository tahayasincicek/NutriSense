import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// NutriSense Modern & Premium Theme
/// Focused on clarity, depth (glassmorphism), and high-end typography.
class AppTheme {
  AppTheme._();

  // --- Brand Colors (Modern Emerald & Slate Palette) ---
  static const Color primaryColor = Color(0xFF10B981); // Emerald 500

  /// Beyaz metin taşıyan yüzeylerde kullanılır (buton dolgusu, seçili sekme).
  ///
  /// Emerald 600 (#059669) beyaza karşı yalnızca 3.14:1 veriyordu; WCAG AA'nın
  /// gövde metni için istediği 4.5:1'i karşılamıyordu. Emerald 800 ile aynı
  /// renk ailesinde kalıp 4.5:1 eşiğinin üstüne çıkıyoruz.
  static const Color primaryDark = Color(0xFF065F46); // Emerald 800
  static const Color primaryLight = Color(0xFFD1FAE5); // Emerald 100

  static const Color secondaryColor =
      Color(0xFF6366F1); // Indigo 500 (for accents)

  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B); // Amber 500
  static const Color errorColor = Color(0xFFEF4444); // Red 500
  static const Color infoColor = Color(0xFF3B82F6); // Blue 500

  // Light Mode Colors
  static const Color lightBg = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF0F172A); // Slate 900
  static const Color lightOnSurfaceMuted = Color(0xFF64748B); // Slate 500
  static const Color lightDivider = Color(0xFFE2E8F0); // Slate 200

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF020617); // Slate 950
  static const Color darkSurface = Color(0xFF0F172A); // Slate 900
  static const Color darkOnSurface = Color(0xFFF1F5F9); // Slate 100
  static const Color darkOnSurfaceMuted = Color(0xFF94A3B8); // Slate 400
  static const Color darkDivider = Color(0xFF1E293B); // Slate 800

  // Radii
  static const double cardRadius = 24.0;
  static const double buttonRadius = 16.0;
  static const double inputRadius = 16.0;

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? darkBg : lightBg;
    final surface = isDark ? darkSurface : lightSurface;
    final onSurface = isDark ? darkOnSurface : lightOnSurface;
    final muted = isDark ? darkOnSurfaceMuted : lightOnSurfaceMuted;
    final divider = isDark ? darkDivider : lightDivider;

    // Dolgu renklerinin üstündeki metin WCAG AA (4.5:1) eşiğini geçmeli.
    //
    // Koyu temada `primary` parlak Emerald 500'dür; koyu yüzeyde vurgu
    // rengi olarak doğru seçim (7:1 kontrast verir) ama üstüne beyaz metin
    // konamaz (2.54:1). Bu yüzden koyu temada onPrimary siyah, aydınlık
    // temada beyazdır. Aynı gerekçeyle hata dolgusu üstünde de koyu metin
    // kullanılır: Red 500 üstüne beyaz yalnızca 3.76:1 verir.
    final onPrimaryColor = isDark ? const Color(0xFF002014) : Colors.white;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: isDark ? primaryColor : primaryDark,
      onPrimary: onPrimaryColor,
      secondary: secondaryColor,
      surface: surface,
      onSurface: onSurface,
      error: errorColor,
      onError: const Color(0xFF2B0000),
      outline: divider,
    );

    // Using Google Fonts for a more premium feel (Inter or Plus Jakarta Sans)
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      TextTheme(
        displayLarge: TextStyle(
            fontWeight: FontWeight.w800, color: onSurface, letterSpacing: -1),
        displayMedium: TextStyle(
            fontWeight: FontWeight.w800, color: onSurface, letterSpacing: -0.5),
        displaySmall: TextStyle(fontWeight: FontWeight.w700, color: onSurface),
        headlineLarge: TextStyle(fontWeight: FontWeight.w700, color: onSurface),
        headlineMedium:
            TextStyle(fontWeight: FontWeight.w700, color: onSurface),
        titleLarge: TextStyle(fontWeight: FontWeight.w600, color: onSurface),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: onSurface),
        bodyLarge: TextStyle(color: onSurface, fontSize: 16),
        bodyMedium: TextStyle(color: onSurface, fontSize: 14),
        bodySmall: TextStyle(color: muted, fontSize: 12),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: divider, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Beyaz metin taşıdığı için dolgu her iki temada da koyu ton.
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurface : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: TextStyle(color: muted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryColor.withOpacity(0.1),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
