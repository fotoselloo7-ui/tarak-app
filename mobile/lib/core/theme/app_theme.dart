import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand Primary & Dark
  static const Color primary = Color(0xFFFF5722);
  static const Color primaryDark = Color(0xFFE64A19);
  static const Color primaryLight = Color(0xFFFFF7ED);
  static const Color primaryBorder = Color(0xFFFFCCBC);

  // Dark Navy & Slates
  static const Color darkNavy = Color(0xFF0F172A);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color secondarySurface = Color(0xFFF1F5F9);
  static const Color cardBg = Colors.white;
  static const Color surface = Colors.white;

  // Typography Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Accessible Semantic Colors
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFDBEAFE);

  // 8pt Spacing Scale
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Border Radii
  static const double radiusSmallValue = 8.0;
  static const double radiusMediumValue = 12.0;
  static const double radiusInputValue = 14.0;
  static const double radiusButtonValue = 14.0;
  static const double radiusCardValue = 18.0;
  static const double radiusSheetValue = 24.0;

  static final BorderRadius radiusSmall = BorderRadius.circular(radiusSmallValue);
  static final BorderRadius radiusMedium = BorderRadius.circular(radiusMediumValue);
  static final BorderRadius radiusInput = BorderRadius.circular(radiusInputValue);
  static final BorderRadius radiusButton = BorderRadius.circular(radiusButtonValue);
  static final BorderRadius radiusCard = BorderRadius.circular(radiusCardValue);
  static const BorderRadius radiusSheet = BorderRadius.vertical(top: Radius.circular(radiusSheetValue));

  // Subtle Premium Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x120F172A),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  // Font family
  static const String fontFamily = 'Poppins';

  // Typography Styles
  static const TextStyle headingLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: slate700,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: darkNavy,
        surface: surface,
        surfaceContainerLowest: Colors.white,
        error: error,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 6,
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButtonValue),
          ),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: slate200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButtonValue),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: slate400,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: slate600,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputValue),
          borderSide: const BorderSide(color: slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputValue),
          borderSide: const BorderSide(color: slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputValue),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputValue),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputValue),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCardValue),
          side: const BorderSide(color: slate200),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: slate200,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
