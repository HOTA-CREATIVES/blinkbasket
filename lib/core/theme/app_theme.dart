import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../design/app_tokens.dart';

/// Single source of truth for the app-wide Material theme.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    // Same brand hue/saturation in both modes, just lifted lighter for dark
    // mode so it keeps enough contrast against dark surfaces — pinning it
    // explicitly (rather than letting the seed derive it) keeps "J C Mart
    // green" recognizable everywhere instead of drifting per-brightness.
    final primary = isLight
        ? AppTokens.primary
        : HSLColor.fromColor(AppTokens.primary).withLightness(0.62).toColor();
    final scheme = ColorScheme.fromSeed(
      seedColor: AppTokens.primary,
      primary: primary,
      brightness: brightness,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? Colors.white : null,
    );

    return base.copyWith(
      // A small, named type scale so screens pull `textTheme.titleMedium`
      // etc. instead of scattering inline `TextStyle(fontSize: n)` literals.
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        headlineSmall: GoogleFonts.poppins(
            fontSize: 24, fontWeight: FontWeight.w800, color: scheme.onSurface), // hero price / big numbers
        titleLarge: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface), // screen/section titles
        titleMedium: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface), // card titles
        titleSmall: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface), // sub-titles / list headers
        bodyLarge: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w500, color: scheme.onSurface),
        bodyMedium: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w400, color: scheme.onSurface),
        bodySmall: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant),
        labelLarge: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface), // button-adjacent labels
        labelMedium: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant), // units/captions
        labelSmall: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant), // badges/pills
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scheme.surface,
        centerTitle: true,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: GoogleFonts.poppins(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: isLight ? 0.4 : 1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16,
          vertical: AppTokens.s12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rPill),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.rXl)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rXl),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
      ),
    );
  }
}
