import 'package:flutter/material.dart';
import 'brand_colors.dart';
import 'role_theme.dart';

/// Centralized UI & Design Constants
class AppDesignTokens {
  AppDesignTokens._();

  // Spacing & Padding
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 18.0;
  static const double radiusFull = 999.0;

  // Elevation / Shadow
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  // Component heights
  static const double buttonHeight = 52.0;
  static const double buttonHeightSm = 40.0;
  static const double inputHeight = 52.0;
  static const double appBarHeight = 56.0;
}

/// Centralized AppTheme builder for Shivnath Agency.
class AppTheme {
  AppTheme._();

  static const Color primaryColor = BrandColors.primaryBlue;
  static const Color secondaryColor = BrandColors.waterBlue;

  /// Default Light Theme (Customer standard)
  static ThemeData get lightTheme => getThemeForRole('customer');

  /// Dynamic Theme parameterized by role
  static ThemeData getThemeForRole(String? roleKey) {
    return getThemeForRoleConfig(RoleTheme.fromKey(roleKey));
  }

  /// Dynamic Theme parameterized by RoleThemeConfig
  static ThemeData getThemeForRoleConfig(RoleThemeConfig roleConfig) {
    final primary = roleConfig.primaryColor;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: roleConfig.secondaryColor,
      surface: BrandColors.surface,
      error: BrandColors.error,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BrandColors.background,
      fontFamily: 'Roboto',

      // -----------------------------------------------------------------------
      // Typography
      // -----------------------------------------------------------------------
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: BrandColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: BrandColors.textPrimary,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: BrandColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: BrandColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: BrandColors.textPrimary,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: BrandColors.textSecondary,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: BrandColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: BrandColors.textSecondary,
        ),
      ),

      // -----------------------------------------------------------------------
      // App Bar Theme
      // -----------------------------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: BrandColors.white,
        foregroundColor: BrandColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: BrandColors.textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: BrandColors.textPrimary,
          size: 22,
        ),
      ),

      // -----------------------------------------------------------------------
      // Input Decoration Theme
      // -----------------------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          borderSide: const BorderSide(color: BrandColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          borderSide: const BorderSide(color: BrandColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          borderSide: BorderSide(
            color: roleConfig.focusBorder,
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          borderSide: const BorderSide(color: BrandColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          borderSide: const BorderSide(color: BrandColors.errorDark, width: 1.8),
        ),
        labelStyle: const TextStyle(
          color: BrandColors.textSecondary,
          fontSize: 14,
        ),
        hintStyle: const TextStyle(
          color: BrandColors.textMuted,
          fontSize: 14,
        ),
      ),

      // -----------------------------------------------------------------------
      // Elevated Button Theme
      // -----------------------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: BrandColors.white,
          minimumSize: const Size(64, AppDesignTokens.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // Outlined Button Theme
      // -----------------------------------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(64, AppDesignTokens.buttonHeight),
          side: BorderSide(color: primary, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // -----------------------------------------------------------------------
      // Card Theme
      // -----------------------------------------------------------------------
      cardTheme: CardThemeData(
        color: BrandColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
          side: const BorderSide(color: BrandColors.border),
        ),
      ),

      // -----------------------------------------------------------------------
      // Bottom Navigation Bar Theme
      // -----------------------------------------------------------------------
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: BrandColors.white,
        selectedItemColor: primary,
        unselectedItemColor: BrandColors.textSecondary,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 6,
      ),

      // -----------------------------------------------------------------------
      // Floating Action Button
      // -----------------------------------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: BrandColors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}