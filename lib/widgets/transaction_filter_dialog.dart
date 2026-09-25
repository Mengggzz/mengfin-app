import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';

class TransactionFilterDialog extends StatefulWidget {
  final TransactionFilter currentFilter;

  const TransactionFilterDialog({super.key, required this.currentFilter});

  @override
  State<TransactionFilterDialog> createState() => _TransactionFilterDialogState();
}

class _TransactionFilterDialogState extends State<TransactionFilterDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late String _jenis;
  late String _kategori;

  @override
  void initState() {
    super.initState();
    _startDate = widget.currentFilter.startDate ?? DateTime.now().subtract(const Duration(days: 30));
    _endDate = widget.currentFilter.endDate ?? DateTime.now();
    _jenis = widget.currentFilter.jenis ?? 'semua';
    _kategori = widget.currentFilter.kategori ?? 'semua';
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme:  ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _reset() {
    setState(() {
      _startDate = DateTime.now().subtract(const Duration(days: 30));
      _endDate = DateTime.now();
      _jenis = 'semua';
      _kategori = 'semua';
    });
  }

  void _apply() {
    Navigator.pop(context, TransactionFilter(
      startDate: _startDate,
      endDate: _endDate,
      jenis: _jenis == 'semua' ? null : _jenis,
      kategori: _kategori == 'semua' ? null : _kategori,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = [...expenseCategories, ...incomeCategories];

    return Container(
      decoration:  BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 16),

          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             Text('Filter Transaksi', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
            TextButton(
              onPressed: _reset,
              child:  Text('Reset', style: TextStyle(color: AppColors.primary)),
            ),
          ]),
          const SizedBox(height: 20),

          // Date Range
           Text('Rentang Tanggal', style: TextStyle(
            color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _dateButton('Dari', _startDate, () => _pickDate(true))),
            const SizedBox(width: 8),
             Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(child: _dateButton('Sampai', _endDate, () => _pickDate(false))),
          ]),
          const SizedBox(height: 20),

          // Type filter
           Text('Jenis Transaksi', style: TextStyle(
            color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            _chip('semua', 'Semua', _jenis, (v) => setState(() => _jenis = v)),
            _chip('pemasukan', 'Pemasukan', _jenis, (v) => setState(() => _jenis = v)),
            _chip('pengeluaran', 'Pengeluaran', _jenis, (v) => setState(() => _jenis = v)),
          ]),
          const SizedBox(height: 20),

          // Category filter
           Text('Kategori', style: TextStyle(
            color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('semua', 'Semua', _kategori, (v) => setState(() => _kategori = v)),
            ...allCategories.map((cat) =>
              _chip(cat.label, '${cat.icon} ${cat.label}', _kategori, (v) => setState(() => _kategori = v))),
          ]),
          const SizedBox(height: 24),

          // Apply button
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Terapkan Filter', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700)),
          )),
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime date, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style:  TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(formatTanggalShort('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
          style:  TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _chip(String value, String label, String current, Function(String) onTap) => GestureDetector(
    onTap: () => onTap(value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: current == value ? AppColors.primary : AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: current == value ? AppColors.primary : AppColors.glassBorder,
        ),
      ),
      child: Text(label, style: TextStyle(
        color: current == value ? Colors.white : AppColors.textSecond,
        fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}

class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? jenis;
  final String? kategori;

  TransactionFilter({
    this.startDate,
    this.endDate,
    this.jenis,
    this.kategori,
  });

  bool get isEmpty => startDate == null && endDate == null && jenis == null && kategori == null;

  int get activeCount {
    int count = 0;
    if (startDate != null || endDate != null) count++;
    if (jenis != null) count++;
    if (kategori != null) count++;
    return count;
  }
}
