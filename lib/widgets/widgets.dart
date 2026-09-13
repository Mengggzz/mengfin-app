import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';

// ─────────────────────────────────────────────────────────────
// GlassCard
// ─────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Gradient? gradient;

  const GlassCard({super.key, required this.child,
    this.padding, this.radius = 20, this.gradient});

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
    if (gradient != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: content,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CurrencyText
// ─────────────────────────────────────────────────────────────
class CurrencyText extends StatelessWidget {
  final double amount;
  final bool short;
  final Color? color;
  final double fontSize;
  final FontWeight? fontWeight;

  const CurrencyText(this.amount, {super.key,
    this.short = false, this.color, this.fontSize = 14, this.fontWeight});

  @override
  Widget build(BuildContext context) {
    return Text(
      short ? formatRupiah(amount) : formatRupiahFull(amount),
      style: TextStyle(
        color: color ?? AppColors.textPrimary,
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.normal,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AppProgressBar
// ─────────────────────────────────────────────────────────────
class AppProgressBar extends StatelessWidget {
  final double value; // 0–100
  final double height;
  final Color? color;

  const AppProgressBar({super.key, required this.value,
    this.height = 8, this.color});

  @override
  Widget build(BuildContext context) {
    final clipped = value.clamp(0.0, 100.0);
    final barColor = color ??
      (clipped >= 90 ? AppColors.danger
       : clipped >= 70 ? AppColors.warning
       : AppColors.success);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: clipped / 100,
        minHeight: height,
        backgroundColor: AppColors.bgElevated,
        valueColor: AlwaysStoppedAnimation(barColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TransaksiTile
// ─────────────────────────────────────────────────────────────
class TransaksiTile extends StatelessWidget {
  final dynamic tx; // Transaksi
  final VoidCallback? onDelete;

  const TransaksiTile({super.key, required this.tx, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final kat = getKategoriInfo(tx.kategori);
    final isIncome = tx.jenis == 'pemasukan';
    final katColor = Color(kat.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: katColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(kat.icon, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            tx.deskripsi.isEmpty ? tx.kategori : tx.deskripsi,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${tx.kategori} · ${tx.metodePembayaran}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ])),
        // Amount
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CurrencyText(tx.nominal, short: true,
            color: isIncome ? AppColors.success : AppColors.textPrimary,
            fontSize: 14, fontWeight: FontWeight.w700),
          const SizedBox(height: 2),
          Text(isIncome ? '+ Masuk' : '- Keluar',
            style: TextStyle(fontSize: 11,
              color: isIncome ? AppColors.success : AppColors.textMuted)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HealthScoreGauge
// ─────────────────────────────────────────────────────────────
class HealthScoreGauge extends StatelessWidget {
  final int score;
  final String status;
  final Color color;
  final double size;

  const HealthScoreGauge({super.key,
    required this.score, required this.status, required this.color, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: size, height: size,
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 10,
            backgroundColor: AppColors.bgElevated,
            valueColor: AlwaysStoppedAnimation(color),
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$score', style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800)),
          Text(status, style: const TextStyle(color: AppColors.textSecond, fontSize: 10)),
        ]),
      ]),
    );
  }
}
