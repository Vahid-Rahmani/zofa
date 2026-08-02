import 'package:flutter/material.dart';

import 'zova_colors.dart';

/// Central theme definition for the zova app.
class ZovaTheme {
  ZovaTheme._();

  static ThemeData get dark => _dark();

  static ThemeData _dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ZovaColors.primary,
        brightness: Brightness.dark,
        primary: ZovaColors.primary,
        secondary: ZovaColors.secondary,
        surface: ZovaColors.surface,
        error: ZovaColors.error,
      ),
      scaffoldBackgroundColor: ZovaColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: ZovaColors.textPrimary,
        displayColor: ZovaColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ZovaColors.background,
        foregroundColor: ZovaColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ZovaColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        color: ZovaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZovaColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZovaColors.textPrimary,
          side: const BorderSide(color: ZovaColors.surfaceRaised),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZovaColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZovaColors.surface,
        hintStyle: const TextStyle(color: ZovaColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ZovaColors.surfaceRaised),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ZovaColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ZovaColors.surface,
        selectedItemColor: ZovaColors.primary,
        unselectedItemColor: ZovaColors.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ZovaColors.surface,
        indicatorColor: ZovaColors.primary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? ZovaColors.primary
                : ZovaColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? ZovaColors.primary
                : ZovaColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZovaColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: ZovaColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ZovaColors.primary,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: ZovaColors.surface,
        side: const BorderSide(color: ZovaColors.surfaceRaised),
        labelStyle: const TextStyle(color: ZovaColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
