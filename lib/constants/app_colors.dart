import 'package:flutter/material.dart';

class AppColors {
  // ── Background ─────────────────────────────────────────────────
  static const Color bg          = Color(0xFF0D1117);
  static const Color bgCard      = Color(0xFF161B22);
  static const Color bgElevated  = Color(0xFF21262D);
  static const Color bgInput     = Color(0xFF1C2128);
  static const Color bgSurface   = Color(0xFF161B22);

  // ── Primary (Neon Turquoise/Cyan) ──────────────────────────────
  static const Color primary     = Color(0xFF00E5FF);
  static const Color primaryLight= Color(0xFF84FFFF);
  static const Color primaryDark = Color(0xFF00B8D4);

  // ── Accent (Neon Purple/Lavender) ──────────────────────────────
  static const Color accent      = Color(0xFFB388FF);
  static const Color accentLight = Color(0xFFD1C4E9);

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecond  = Color(0xFF8B949E);
  static const Color textMuted   = Color(0xFF6E7681);
  static const Color textHint    = Color(0xFF484F58);

  // ── Status ─────────────────────────────────────────────────────
  static const Color success     = Color(0xFF00E676);
  static const Color successLight= Color(0xFF69F0AE);
  static const Color warning     = Color(0xFFFFD600);
  static const Color danger      = Color(0xFFFF1744);
  static const Color dangerDark  = Color(0xFFD50000);
  static const Color info        = Color(0xFF00E5FF);

  // ── Income / Expense ───────────────────────────────────────────
  static const Color income      = Color(0xFF00E676);
  static const Color expense     = Color(0xFFFF1744);

  // ── Glass / Border ─────────────────────────────────────────────
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassBg     = Color(0x0AFFFFFF);
  static const Color divider     = Color(0xFF30363D);

  // ── Numpad ─────────────────────────────────────────────────────
  static const Color numpadBg    = Color(0xFF0D1117);
  static const Color numpadKey   = Color(0xFF161B22);
  static const Color numpadOp    = Color(0xFF21262D);
  static const Color numpadDel   = Color(0xFFFF1744);
  static const Color numpadEq    = Color(0xFFB388FF);
  static const Color numpadOk    = Color(0xFF00E676);

  // ── Category Tag Colors ────────────────────────────────────────
  static const Color catFood     = Color(0xFFFF6D00);
  static const Color catTransport= Color(0xFF00E5FF);
  static const Color catShopping = Color(0xFFFF4081);
  static const Color catHealth   = Color(0xFF00E676);
  static const Color catEntertain= Color(0xFFE040FB);
  static const Color catBills    = Color(0xFFFF1744);
  static const Color catEducation= Color(0xFF651FFF);
  static const Color catSalary   = Color(0xFF00E5FF);
  static const Color catInvest   = Color(0xFF651FFF);

  // ── Gradients ──────────────────────────────────────────────────
  static const List<Color> gradientPrimary = [Color(0xFF00E5FF), Color(0xFF00B8D4)];
  static const List<Color> gradientIncome  = [Color(0xFF00E676), Color(0xFF00C853)];
  static const List<Color> gradientExpense = [Color(0xFFFF1744), Color(0xFFD50000)];
  static const List<Color> gradientGold    = [Color(0xFFFFD600), Color(0xFFFFC400)];
  static const List<Color> gradientBlue    = [Color(0xFFB388FF), Color(0xFF651FFF)];
  static const List<Color> gradientPurple  = [Color(0xFFE040FB), Color(0xFFAA00FF)];

  // ── Need / Want / Saving ───────────────────────────────────────
  static const Color typeNeed    = Color(0xFF00E5FF);
  static const Color typeWant    = Color(0xFFFFD600);
  static const Color typeSaving  = Color(0xFF00E676);
}
