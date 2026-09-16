import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  final VoidCallback? onTap;

  const GlassCard({super.key, required this.child,
    this.padding, this.radius = 16, this.gradient, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
    final decoration = BoxDecoration(
      gradient: gradient,
      color: gradient == null ? AppColors.bgCard : null,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.glassBorder),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(decoration: decoration, child: content),
      );
    }
    return Container(decoration: decoration, child: content);
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
  final String? prefix;

  const CurrencyText(this.amount, {super.key,
    this.short = false, this.color, this.fontSize = 14,
    this.fontWeight, this.prefix});

  @override
  Widget build(BuildContext context) {
    final text = prefix != null
        ? '$prefix${short ? formatRupiah(amount) : formatRupiahFull(amount)}'
        : short ? formatRupiah(amount) : formatRupiahFull(amount);
    return Text(
      text,
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
  final Color? bgColor;

  const AppProgressBar({super.key, required this.value,
    this.height = 8, this.color, this.bgColor});

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
        backgroundColor: bgColor ?? AppColors.bgElevated,
        valueColor: AlwaysStoppedAnimation(barColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TransaksiTile — Updated for Kazz style
// ─────────────────────────────────────────────────────────────
class TransaksiTile extends StatelessWidget {
  final dynamic tx;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const TransaksiTile({super.key, required this.tx, this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) {
    final kat = getKategoriInfo(tx.kategori);
    final isIncome = tx.jenis == 'pemasukan';
    final katColor = Color(kat.color);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(children: [
          // Category icon
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: katColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(kat.icon, style: const TextStyle(fontSize: 18))),
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
              tx.tanggal.length > 10
                  ? '${formatTanggalShort(tx.tanggal.substring(0, 10))} ${formatTime(tx.tanggal)}'
                  : formatTanggalShort(tx.tanggal),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ])),
          // Amount
          Text(
            '${isIncome ? '+' : '-'}Rp ${formatAmount(tx.nominal)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isIncome ? AppColors.income : AppColors.expense,
            ),
          ),
        ]),
      ),
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

// ─────────────────────────────────────────────────────────────
// DonutChart — Wraps fl_chart PieChart
// ─────────────────────────────────────────────────────────────
class DonutChart extends StatelessWidget {
  final List<DonutChartData> data;
  final double size;
  final String? centerText;
  final String? centerSubText;
  final Color? centerTextColor;

  const DonutChart({
    super.key,
    required this.data,
    this.size = 120,
    this.centerText,
    this.centerSubText,
    this.centerTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final total = data.fold(0.0, (s, d) => s + d.value);
    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        PieChart(PieChartData(
          sections: data.map((d) => PieChartSectionData(
            value: d.value,
            color: d.color,
            radius: 16,
            showTitle: false,
          )).toList(),
          centerSpaceRadius: size / 2 - 20,
          sectionsSpace: 2,
          startDegreeOffset: -90,
        )),
        if (centerText != null)
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(centerText!, style: TextStyle(
              color: centerTextColor ?? AppColors.textPrimary,
              fontSize: 11, fontWeight: FontWeight.w600)),
            if (centerSubText != null)
              Text(centerSubText!, style: TextStyle(
                color: centerTextColor ?? AppColors.textSecond,
                fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
      ]),
    );
  }
}

class DonutChartData {
  final String label;
  final double value;
  final Color color;
  const DonutChartData({required this.label, required this.value, required this.color});
}

// ─────────────────────────────────────────────────────────────
// SegmentedTab — Kazz style segment control
// ─────────────────────────────────────────────────────────────
class SegmentedTab extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  const SegmentedTab({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: List.generate(tabs.length, (i) {
        final isActive = i == selectedIndex;
        return Expanded(child: GestureDetector(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(tabs[i], style: TextStyle(
              color: isActive ? Colors.white : AppColors.textMuted,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ))),
          ),
        ));
      })),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// KazzWalletCard — For wallet display in Kazz screen
// ─────────────────────────────────────────────────────────────
class KazzWalletCard extends StatelessWidget {
  final String name;
  final double balance;
  final String icon;
  final VoidCallback? onTap;
  final bool isSelected;

  const KazzWalletCard({
    super.key,
    required this.name,
    required this.balance,
    this.icon = '💰',
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
            ),
            const Icon(Icons.more_vert, color: AppColors.textMuted, size: 18),
          ]),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            '${balance < 0 ? '-' : ''}Rp ${formatAmount(balance.abs())}',
            style: TextStyle(
              color: balance < 0 ? AppColors.expense : AppColors.textSecond,
              fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AddKazzCard — Dashed border "Tambah Kazz" card
// ─────────────────────────────────────────────────────────────
class AddKazzCard extends StatelessWidget {
  final VoidCallback? onTap;
  const AddKazzCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_circle_outline, color: AppColors.textMuted, size: 36),
            SizedBox(height: 8),
            Text('Tambah Kazz', style: TextStyle(
              color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// CategoryIconGrid — Grid of category icons for transaction input
// ─────────────────────────────────────────────────────────────
class CategoryIconGrid extends StatelessWidget {
  final List<KategoriInfo> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;
  final int crossAxisCount;

  const CategoryIconGrid({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
    this.crossAxisCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((k) {
        final isActive = selectedCategory == k.label;
        return GestureDetector(
          onTap: () => onSelected(k.label),
          child: SizedBox(
            width: (MediaQuery.of(context).size.width - 48 - (8 * (crossAxisCount - 1))) / crossAxisCount,
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isActive ? Color(k.color).withOpacity(0.25) : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive ? Color(k.color) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(child: Text(k.icon, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(height: 4),
              Text(k.label, style: TextStyle(
                color: isActive ? Color(k.color) : AppColors.textMuted,
                fontSize: 9, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CalcNumpad — Calculator-style number pad
// ─────────────────────────────────────────────────────────────
class CalcNumpad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;
  final VoidCallback onConfirm;
  final VoidCallback? onEquals;

  const CalcNumpad({
    super.key,
    required this.onKey,
    required this.onDelete,
    required this.onConfirm,
    this.onEquals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.numpadBg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(children: [
        // Row 1: 1, 2, 3, Backspace
        _row([
          _numKey('1'), _numKey('2'), _numKey('3'),
          _specialKey(Icons.backspace_outlined, AppColors.numpadDel, onDelete),
        ]),
        const SizedBox(height: 6),
        // Row 2: 4, 5, 6, Operators
        _row([
          _numKey('4'), _numKey('5'), _numKey('6'),
          _opGroup(),
        ]),
        const SizedBox(height: 6),
        // Row 3: 7, 8, 9, Equals
        _row([
          _numKey('7'), _numKey('8'), _numKey('9'),
          _specialKey(Icons.drag_handle, AppColors.numpadEq, onEquals ?? () {}),
        ]),
        const SizedBox(height: 6),
        // Row 4: 0, 000, Confirm
        _row([
          _numKey('0'), _numKey('000'),
          _confirmKey(),
        ]),
      ]),
    );
  }

  Widget _row(List<Widget> children) => Row(
    children: children.map((c) => Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: c,
    ))).toList(),
  );

  Widget _numKey(String val) => GestureDetector(
    onTap: () => onKey(val),
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.numpadKey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(val, style: const TextStyle(
        color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600))),
    ),
  );

  Widget _specialKey(IconData icon, Color color, VoidCallback action) => GestureDetector(
    onTap: action,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Icon(icon, color: color, size: 24)),
    ),
  );

  Widget _opGroup() => GestureDetector(
    onTap: () {},
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.numpadOp.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _opBtn('+'), _opBtn('-'),
        const Text('×', style: TextStyle(color: AppColors.textSecond, fontSize: 14)),
        const Text('÷', style: TextStyle(color: AppColors.textSecond, fontSize: 14)),
      ]),
    ),
  );

  Widget _opBtn(String op) => GestureDetector(
    onTap: () => onKey(op),
    child: Text(op, style: const TextStyle(color: AppColors.textSecond, fontSize: 14, fontWeight: FontWeight.w600)),
  );

  Widget _confirmKey() => GestureDetector(
    onTap: onConfirm,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.numpadOk,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: Icon(Icons.check, color: Colors.white, size: 28)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// QuickActionButton — Pill button for dashboard quick actions
// ─────────────────────────────────────────────────────────────
class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: iconColor ?? AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TransactionTypeSelector — Need / Want / Saving tags
// ─────────────────────────────────────────────────────────────
class TransactionTypeSelector extends StatelessWidget {
  final TransactionType? selected;
  final ValueChanged<TransactionType> onSelected;

  const TransactionTypeSelector({
    super.key,
    this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      ...transactionTypes.map((t) {
        final isActive = selected == t.type;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelected(t.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Color(t.color).withOpacity(0.2) : AppColors.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? Color(t.color) : AppColors.glassBorder,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(t.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(t.label, style: TextStyle(
                  color: isActive ? Color(t.color) : AppColors.textMuted,
                  fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
      }),
      if (selected != null)
        Expanded(child: Text(
          transactionTypes.firstWhere((t) => t.type == selected).description,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          maxLines: 2,
        )),
    ]);
  }
}
