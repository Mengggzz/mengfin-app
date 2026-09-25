import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ThemeData untuk mode terang & gelap.
///
/// Layar-layar di aplikasi ini mengambil warna langsung dari [AppColors],
/// jadi tema di sini terutama mengatur komponen bawaan Material (dialog,
/// date picker, snackbar, bottom sheet, input) supaya ikut mode terang.
class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;

    final scheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFF00E5FF),
            secondary: Color(0xFFB388FF),
            surface: Color(0xFF161B22),
            error: Color(0xFFFF1744),
          )
        : const ColorScheme.light(
            primary: Color(0xFF0E7490),
            secondary: Color(0xFF6D28D9),
            surface: Color(0xFFFFFFFF),
            error: Color(0xFFBE123C),
          );

    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF2F5F9);
    final card = isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);
    final elevated = isDark ? const Color(0xFF21262D) : const Color(0xFFE9EEF5);
    final textPrimary =
        isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
    final textMuted =
        isDark ? const Color(0xFF6E7681) : const Color(0xFF64748B);
    final border = isDark ? const Color(0x33FFFFFF) : const Color(0x1F0F172A);

    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: isDark ? const Color(0xFF30363D) : const Color(0xFFD8E0EA),
      splashColor: scheme.primary.withOpacity(0.2),
      highlightColor: scheme.primary.withOpacity(0.1),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: isDark ? const Color(0xFF8B949E) : const Color(0xFF475569),
          fontSize: 13.5,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevated,
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C2128) : const Color(0xFFFFFFFF),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF484F58) : const Color(0xFF94A3B8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF30363D) : const Color(0xFFD8E0EA),
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textMuted,
        textColor: textPrimary,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: elevated,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary.withOpacity(0.35)
              : (isDark ? const Color(0xFF21262D) : const Color(0xFFDCE4EE)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : textMuted,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
        ),
        side: BorderSide(color: textMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      // Date picker ikut mode supaya tidak putih mentah di mode gelap.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: isDark ? const Color(0xFF21262D) : scheme.primary,
        headerForegroundColor: isDark ? textPrimary : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }

  /// Border tipis khas kartu aplikasi ini.
  static Color borderColor() => AppColors.glassBorder;
}
