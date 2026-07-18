import 'package:flutter/material.dart';

/// Visual tokens adapted from the referenced Nutrition App Figma community file.
///
/// The source uses a monochrome palette, white surfaces, 40% black secondary
/// content, fine separators, compact Inter typography and small-radius cards.
/// Touch targets and readable text sizes remain larger than the source mockup so
/// the existing accessibility contract is not weakened.
class AppTheme {
  AppTheme._();

  static const Color primaryColor = Color(0xFF111111);
  static const Color primaryLight = Color(0xFF4D4D4D);
  static const Color primaryDark = Color(0xFF000000);

  static const Color accentColor = Color(0xFF666666);
  static const Color accentLight = Color(0xFF8A8A8A);

  static const Color successColor = Color(0xFF2E6A45);
  static const Color warningColor = Color(0xFF8A5700);
  static const Color errorColor = Color(0xFFB3261E);
  static const Color infoColor = Color(0xFF315C75);

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF111111);
  static const Color lightOnSurfaceVariant = Color(0xFF737373);
  static const Color lightDivider = Color(0xFFD8D8D8);
  static const Color lightMuted = Color(0xFFF5F5F5);

  static const Color darkBackground = Color(0xFF0F0F0F);
  static const Color darkSurface = Color(0xFF181818);
  static const Color darkOnSurface = Color(0xFFF7F7F7);
  static const Color darkOnSurfaceVariant = Color(0xFFAAAAAA);
  static const Color darkDivider = Color(0xFF3D3D3D);

  /// Figma cards use a 5 px radius on a 220 px artboard. At normal mobile
  /// scale that corresponds to approximately 8 px.
  static const double cardRadius = 8;
  static const double controlRadius = 8;
  static const double sheetRadius = 24;

  static TextTheme _textTheme(Color text, Color muted) => TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          height: 1.12,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: text,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          height: 1.16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: text,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: text,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          height: 1.22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
          color: text,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: text,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
          color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: text,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.48,
          fontWeight: FontWeight.w400,
          color: text,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: text,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
      );

  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? darkBackground : lightBackground;
    final surface = dark ? darkSurface : lightSurface;
    final onSurface = dark ? darkOnSurface : lightOnSurface;
    final muted = dark ? darkOnSurfaceVariant : lightOnSurfaceVariant;
    final divider = dark ? darkDivider : lightDivider;
    final primary = dark ? darkOnSurface : primaryColor;
    final onPrimary = dark ? darkBackground : Colors.white;
    final fieldFill = dark ? const Color(0xFF222222) : lightMuted;

    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: primary,
      surface: surface,
      error: dark ? const Color(0xFFFFB4AB) : errorColor,
    ).copyWith(
      onPrimary: onPrimary,
      onSurface: onSurface,
      surfaceContainer: fieldFill,
      outline: divider,
      outlineVariant: divider,
    );

    final textTheme = _textTheme(onSurface, muted);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardRadius),
      side: BorderSide(color: divider, width: 0.8),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: onSurface, size: 24),
        shape: Border(bottom: BorderSide(color: divider, width: 0.8)),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        shape: cardShape,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: divider,
          disabledForegroundColor: muted,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(48, 52),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          backgroundColor: surface,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          side: BorderSide(color: onSurface, width: 1),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: onSurface, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: onSurface,
        unselectedItemColor: muted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedIconTheme: const IconThemeData(size: 26),
        unselectedIconTheme: const IconThemeData(size: 24),
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(color: muted),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: onSurface,
        foregroundColor: surface,
        elevation: 1,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 2,
        shape: const CircleBorder(),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 0.8, space: 24),
      iconTheme: IconThemeData(color: onSurface, size: 24),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface,
        textColor: onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        minTileHeight: 56,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: onSurface,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: surface),
        side: BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(),
        side: BorderSide(color: muted, width: 1),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onSurface : null,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? onSurface : divider,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: onSurface,
        linearTrackColor: divider,
        circularTrackColor: divider,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(sheetRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sheetRadius),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: surface),
        behavior: SnackBarBehavior.floating,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: fieldFill,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
    );
  }
}
