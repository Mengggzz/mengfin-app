import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  List<Transaksi> _monthTx = [];
  bool _loading = true;
  String _filter = 'pengeluaran'; // pengeluaran, pemasukan, semua

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bulan = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
      final data = await ApiService.getTransaksi(limit: 500);
      setState(() {
        _monthTx = data.where((tx) {
          final txDate = DateTime.tryParse(tx.tanggal);
          if (txDate == null) return false;
          return txDate.year == _selectedMonth.year && txDate.month == _selectedMonth.month;
        }).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Transaksi> get _filteredTx {
    if (_filter == 'semua') return _monthTx;
    return _monthTx.where((tx) => tx.jenis == _filter).toList();
  }

  List<Transaksi> get _selectedDayTx {
    return _filteredTx.where((tx) {
      final txDate = DateTime.tryParse(tx.tanggal);
      if (txDate == null) return false;
      return txDate.year == _selectedDate.year &&
             txDate.month == _selectedDate.month &&
             txDate.day == _selectedDate.day;
    }).toList();
  }

  Map<int, double> get _dayTotals {
    final map = <int, double>{};
    for (final tx in _filteredTx) {
      final txDate = DateTime.tryParse(tx.tanggal);
      if (txDate == null) continue;
      map[txDate.day] = (map[txDate.day] ?? 0) + tx.nominal;
    }
    return map;
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _selectedDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    });
    _load();
  }

  // ══════════════════════════════════════════════════════════════
  // 5. Hapus Transaksi
  // ══════════════════════════════════════════════════════════════
  Future<void> _hapusTransaksi(dynamic tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title:  Text('Hapus Transaksi?', style: TextStyle(color: AppColors.textPrimary)),
        content:  Text('Tindakan ini tidak dapat dibatalkan.', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child:  Text('Batal', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child:  Text('Hapus', style: TextStyle(color: AppColors.expense))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (tx.id != null) {
        await ApiService.deleteTransaksi(tx.id);
      }
      _load(); // Refresh UI
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal menghapus: $e'), backgroundColor: AppColors.expense,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday; // 1=Mon
    final dayTotals = _dayTotals;
    final selectedDayTx = _selectedDayTx;
    final totalForDay = selectedDayTx.fold(0.0, (s, tx) => s + tx.nominal);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title:  Text('Peta Kalender', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ?  Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        // ── Date range ─────────────────────────────────────
        Row(children: [
           Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            '1 ${formatBulanShort('${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}')} – '
            '$daysInMonth ${formatBulanShort('${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}')}',
            style:  TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ]),
        const SizedBox(height: 8),

        // ── Wallet filter ──────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child:  Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Dompet Utama', style: TextStyle(
              color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Type filter circles ─────────────────────────────
        Row(children: [
          _typeFilterCircle(Icons.arrow_upward, AppColors.expense, 'pengeluaran'),
          const SizedBox(width: 8),
          _typeFilterCircle(Icons.arrow_downward, AppColors.income, 'pemasukan'),
          const SizedBox(width: 8),
          _typeFilterCircle(Icons.swap_horiz, AppColors.info, 'semua'),
          const SizedBox(width: 12),
          Text(_filter == 'pengeluaran' ? 'PENGELUARAN' : _filter == 'pemasukan' ? 'PEMASUKAN' : 'SEMUA',
            style: TextStyle(
              color: _filter == 'pengeluaran' ? AppColors.expense : _filter == 'pemasukan' ? AppColors.income : AppColors.info,
              fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 16),

        // ── Month Navigation ─────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(onPressed: () => _changeMonth(-1),
            icon:  Icon(Icons.chevron_left, color: AppColors.textSecond)),
          Text(
            formatBulan('${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}'),
            style:  TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          IconButton(onPressed: () => _changeMonth(1),
            icon:  Icon(Icons.chevron_right, color: AppColors.textSecond)),
        ]),
        const SizedBox(height: 8),

        // ── Day headers ──────────────────────────────────────
        Row(children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].map((d) =>
          Expanded(child: Center(child: Text(d, style: TextStyle(
            color: d == 'Sab' || d == 'Min' ? AppColors.textMuted.withOpacity(0.5) : AppColors.textMuted,
            fontSize: 12, fontWeight: FontWeight.w600))))).toList()),
        const SizedBox(height: 8),

        // ── Calendar Grid ────────────────────────────────────
        _buildCalendarGrid(daysInMonth, firstWeekday, dayTotals),
        const SizedBox(height: 16),

        // ── Selected day transactions ────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              '${_selectedDate.day} ${formatBulanShort('${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}')}',
              style:  TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(
              '${selectedDayTx.length} transaksi · Rp ${formatAmount(totalForDay)}',
              style:  TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
        if (selectedDayTx.isEmpty)
           Padding(padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Tidak ada transaksi pada hari ini',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13))))
        else
          ...selectedDayTx.map((tx) => TransaksiTile(
            tx: tx,
            onDelete: () => _hapusTransaksi(tx),
          )),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _typeFilterCircle(IconData icon, Color color, String type) => GestureDetector(
    onTap: () => setState(() => _filter = type),
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: _filter == type ? color : color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, size: 16,
        color: _filter == type ? Colors.white : color),
    ),
  );

  Widget _buildCalendarGrid(int daysInMonth, int firstWeekday, Map<int, double> dayTotals) {
    final cells = <Widget>[];

    // Empty cells before first day
    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final hasData = dayTotals.containsKey(day);
      final isSelected = _selectedDate.day == day &&
                          _selectedDate.month == _selectedMonth.month &&
                          _selectedDate.year == _selectedMonth.year;
      final isToday = day == DateTime.now().day &&
                      _selectedMonth.month == DateTime.now().month &&
                      _selectedMonth.year == DateTime.now().year;

      cells.add(GestureDetector(
        onTap: () => setState(() {
          _selectedDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
        }),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: AppColors.primary, width: 1.5) : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day', style: TextStyle(
              color: isToday ? AppColors.primary : isSelected ? AppColors.primary : AppColors.textPrimary,
              fontSize: 14, fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400)),
            if (hasData)
              Text(formatRupiah(dayTotals[day]!).replaceFirst('Rp ', ''),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 8, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.85,
      children: cells,
    );
  }
}
