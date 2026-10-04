import 'package:flutter/material.dart';

/// Palet warna aplikasi.
///
/// Sebagian warna berubah mengikuti mode terang/gelap: latar, teks, border,
/// aksen, dan warna status. Nilai mode GELAP sama dengan palet lama, jadi
/// tampilan gelap tidak berubah.
///
/// Karena warnanya dinamis, JANGAN menaruhnya di dalam `const`
/// (mis. `const TextStyle(color: AppColors.textPrimary)`) — itu gagal
/// dikompilasi. Pakai `TextStyle(color: AppColors.textPrimary)` biasa.
/// Gradien tetap `const` sehingga aman dipakai di dalam `const`.
class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.dark;

  /// Dipanggil ThemeService setiap mode tampilan berubah.
  static void applyBrightness(Brightness b) => _brightness = b;

  /// Terapkan brightness sesuai ThemeMode. ThemeMode.system memakai
  /// brightness platform yang sedang aktif.
  static void applyBrightnessForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        applyBrightness(Brightness.dark);
      case ThemeMode.light:
        applyBrightness(Brightness.light);
      case ThemeMode.system:
        final p = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        applyBrightness(p);
    }
  }

  static Brightness get brightness => _brightness;
  static bool get isDark => _brightness == Brightness.dark;

  static Color _pick(Color dark, Color light) => isDark ? dark : light;

  // ── Background ─────────────────────────────────────────────────
  static Color get bg         => _pick(const Color(0xFF0D1117), const Color(0xFFF2F5F9));
  static Color get bgCard     => _pick(const Color(0xFF161B22), const Color(0xFFFFFFFF));
  static Color get bgElevated => _pick(const Color(0xFF21262D), const Color(0xFFE9EEF5));
  static Color get bgInput    => _pick(const Color(0xFF1C2128), const Color(0xFFFFFFFF));
  static Color get bgSurface  => _pick(const Color(0xFF161B22), const Color(0xFFFFFFFF));

  // ── Primary (Neon Turquoise/Cyan → Teal gelap untuk mode terang) ─
  static Color get primary     => _pick(const Color(0xFF00E5FF), const Color(0xFF0E7490));
  static Color get primaryLight=> _pick(const Color(0xFF84FFFF), const Color(0xFF0891B2));
  static Color get primaryDark => _pick(const Color(0xFF00B8D4), const Color(0xFF155E75));

  // ── Accent (Neon Purple/Lavender) ──────────────────────────────
  static Color get accent      => _pick(const Color(0xFFB388FF), const Color(0xFF6D28D9));
  static const Color accentLight = Color(0xFFD1C4E9);

  // ── Text ───────────────────────────────────────────────────────
  static Color get textPrimary => _pick(const Color(0xFFFFFFFF), const Color(0xFF0F172A));
  static Color get textSecond  => _pick(const Color(0xFF8B949E), const Color(0xFF475569));
  static Color get textMuted   => _pick(const Color(0xFF6E7681), const Color(0xFF64748B));
  static Color get textHint    => _pick(const Color(0xFF484F58), const Color(0xFF94A3B8));

  // ── Status ─────────────────────────────────────────────────────
  static Color get success     => _pick(const Color(0xFF00E676), const Color(0xFF047857));
  static const Color successLight= Color(0xFF69F0AE);
  static Color get warning     => _pick(const Color(0xFFFFD600), const Color(0xFFA16207));
  static Color get danger      => _pick(const Color(0xFFFF1744), const Color(0xFFBE123C));
  static const Color dangerDark = Color(0xFFD50000);
  static Color get info        => _pick(const Color(0xFF00E5FF), const Color(0xFF0369A1));

  // ── Income / Expense ───────────────────────────────────────────
  static Color get income      => _pick(const Color(0xFF00E676), const Color(0xFF047857));
  static Color get expense     => _pick(const Color(0xFFFF1744), const Color(0xFFBE123C));

  // ── Glass / Border ─────────────────────────────────────────────
  static Color get glassBorder => _pick(const Color(0x33FFFFFF), const Color(0x1F0F172A));
  static Color get glassBg     => _pick(const Color(0x0AFFFFFF), const Color(0x0A0F172A));
  static Color get divider     => _pick(const Color(0xFF30363D), const Color(0xFFD8E0EA));

  // ── Slate (menu Kazz: pill aktif, panel saldo) ─────────────────
  // Slate dipakai supaya menu Kazz terlihat kalem dan tidak "menyala"
  // seperti aksen cyan utama.
  static Color get slate     => _pick(const Color(0xFF46587A), const Color(0xFF334155));
  static Color get slateSoft => _pick(const Color(0xFF2C2C2E), const Color(0xFFE2E8F0));
  /// Garis putus-putus panel Saldo.
  static Color get dashLine  => _pick(const Color(0xFF3E4C66), const Color(0xFF94A3B8));

  // ── Numpad ─────────────────────────────────────────────────────
  static Color get numpadBg  => _pick(const Color(0xFF0D1117), const Color(0xFFE9EEF5));
  static Color get numpadKey => _pick(const Color(0xFF161B22), const Color(0xFFFFFFFF));
  static Color get numpadOp  => _pick(const Color(0xFF21262D), const Color(0xFFDCE4EE));
  static Color get numpadDel => _pick(const Color(0xFFFF1744), const Color(0xFFBE123C));
  static Color get numpadEq  => _pick(const Color(0xFFB388FF), const Color(0xFF6D28D9));
  static Color get numpadOk  => _pick(const Color(0xFF00E676), const Color(0xFF047857));

  // ── Category Tag Colors ────────────────────────────────────────
  static Color get catFood     => _pick(const Color(0xFFFF6D00), const Color(0xFFC2410C));
  static Color get catTransport=> _pick(const Color(0xFF00E5FF), const Color(0xFF0369A1));
  static Color get catShopping => _pick(const Color(0xFFFF4081), const Color(0xFFBE185D));
  static Color get catHealth   => _pick(const Color(0xFF00E676), const Color(0xFF047857));
  static Color get catEntertain=> _pick(const Color(0xFFE040FB), const Color(0xFF7E22CE));
  static Color get catBills    => _pick(const Color(0xFFFF1744), const Color(0xFFBE123C));
  static Color get catEducation=> _pick(const Color(0xFF651FFF), const Color(0xFF4C1D95));
  static Color get catSalary   => _pick(const Color(0xFF00E5FF), const Color(0xFF0369A1));
  static Color get catInvest   => _pick(const Color(0xFF651FFF), const Color(0xFF4C1D95));

  // ── Gradients (tetap `const`, aman di kedua mode) ──────────────
  static const List<Color> gradientPrimary = [Color(0xFF00E5FF), Color(0xFF00B8D4)];
  static const List<Color> gradientIncome  = [Color(0xFF00E676), Color(0xFF00C853)];
  static const List<Color> gradientExpense = [Color(0xFFFF1744), Color(0xFFD50000)];
  static const List<Color> gradientGold    = [Color(0xFFFFD600), Color(0xFFFFC400)];
  static const List<Color> gradientBlue    = [Color(0xFFB388FF), Color(0xFF651FFF)];
  static const List<Color> gradientPurple  = [Color(0xFFE040FB), Color(0xFFAA00FF)];

  // ── Need / Want / Saving ───────────────────────────────────────
  static Color get typeNeed    => _pick(const Color(0xFF00E5FF), const Color(0xFF0369A1));
  static Color get typeWant    => _pick(const Color(0xFFFFD600), const Color(0xFFA16207));
  static Color get typeSaving  => _pick(const Color(0xFF00E676), const Color(0xFF047857));

  // ── Analytics Chart Palette (variatif & presisi) ───────────────
  // Status bar berdasarkan % pemakaian budget: aman → hampir → lewat
  static Color get chartSafe   => _pick(const Color(0xFF00E5FF), const Color(0xFF0E7490)); // 0-70%
  static Color get chartWarn   => _pick(const Color(0xFFFFB020), const Color(0xFFB45309)); // 70-100%
  static Color get chartOver   => _pick(const Color(0xFFFF2D55), const Color(0xFFBE123C)); // >100%

  static const List<Color> gradientChartSafe = [Color(0xFF22D3EE), Color(0xFF0EA5B7)];
  static const List<Color> gradientChartWarn = [Color(0xFFFFC53D), Color(0xFFFF8A00)];
  static const List<Color> gradientChartOver = [Color(0xFFFF5C7A), Color(0xFFE11D48)];

  // Garis & area budget harian
  static const List<Color> gradientBudgetLine = [Color(0xFFB388FF), Color(0xFF7C4DFF)];

  // Gradien tambahan untuk aksen modern
  static const List<Color> gradientSunset = [Color(0xFFFF9A3C), Color(0xFFFF5C7A)];
  static const List<Color> gradientOcean  = [Color(0xFF22D3EE), Color(0xFF3B82F6)];
  static const List<Color> gradientMint   = [Color(0xFF34D399), Color(0xFF0EA5B7)];
  static const List<Color> gradientViolet = [Color(0xFFA78BFA), Color(0xFF7C3AED)];

  /// Warna gradien bar sesuai rasio pemakaian budget (0..∞).
  static List<Color> barGradientFor(double ratio) {
    if (ratio > 1.0) return gradientChartOver;
    if (ratio >= 0.7) return gradientChartWarn;
    return gradientChartSafe;
  }

  /// Warna solid bar sesuai rasio pemakaian budget.
  static Color barColorFor(double ratio) {
    if (ratio > 1.0) return chartOver;
    if (ratio >= 0.7) return chartWarn;
    return chartSafe;
  }
}
