import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';

class TransactionInputScreen extends StatefulWidget {
  final String? initialDeskripsi;

  const TransactionInputScreen({super.key, this.initialDeskripsi});
  @override State<TransactionInputScreen> createState() => _TransactionInputScreenState();
}

class _TransactionInputScreenState extends State<TransactionInputScreen> {
  bool _isExpense = true; // true = pengeluaran, false = pemasukan
  String _amount = '0';
  String _deskripsi = '';
  String _kategori = 'Makan & Minum';
  String _tanggal = currentTanggal();
  String _walletName = 'Dompet Utama';
  TransactionType? _tipe;
  bool _saving = false;

  late final TextEditingController _deskripsiCtrl;

  // Recent descriptions for suggestions
  final _recentDescs = <String>['kopi', 'bensin', 'makan siang', 'grab', 'belanja'];

  @override
  void initState() {
    super.initState();
    _deskripsi = widget.initialDeskripsi ?? '';
    _deskripsiCtrl = TextEditingController(text: _deskripsi);
  }

  @override
  void dispose() {
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  void _onNumKey(String key) {
    setState(() {
      if (key == '000') {
        if (_amount != '0') _amount += '000';
      } else if (key == '+' || key == '-' || key == '×' || key == '÷') {
        // Simple operator append — for display purpose
        _amount += ' $key ';
      } else {
        if (_amount == '0') {
          _amount = key;
        } else {
          _amount += key;
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (_amount.length <= 1) {
        _amount = '0';
      } else {
        _amount = _amount.substring(0, _amount.length - 1).trimRight();
        if (_amount.isEmpty) _amount = '0';
      }
    });
  }

  double _parseAmount() {
    // Remove spaces and operators, just get the numeric value
    final cleaned = _amount.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  Future<void> _onConfirm() async {
    final nominal = _parseAmount();
    if (nominal <= 0 || _saving) return;

    setState(() => _saving = true);
    try {
      await ApiService.createTransaksi({
        'tanggal': _tanggal,
        'jenis': _isExpense ? 'pengeluaran' : 'pemasukan',
        'nominal': nominal,
        'kategori': _kategori,
        'deskripsi': _deskripsi,
        'metode_pembayaran': 'tunai',
      });

      if (_isExpense && mounted) {
        // Smart Budgeting Check
        final bulan = _tanggal.substring(0, 7);
        final anggarans = await ApiService.getAnggaran(bulan);
        try {
          final anggaran = anggarans.firstWhere((a) => a.kategori == _kategori);
          if (anggaran.terpakai > anggaran.batas) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Perhatian: Anggaran $_kategori bulan ini telah melebihi batas!')),
              ]),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
            ));
          } else if (anggaran.terpakai >= anggaran.batas * 0.8) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Peringatan: Anggaran $_kategori hampir habis (sisa ${formatRupiah(anggaran.batas - anggaran.terpakai)}).')),
              ]),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 4),
            ));
          }
        } catch (_) {
          // No budget set for this category, ignore
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_tanggal) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _tanggal = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isExpense ? expenseCategories : incomeCategories;
    if (!categories.any((c) => c.label == _kategori)) {
      _kategori = categories.first.label;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Transaksi', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Column(children: [
        // Scrollable top section
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Expense / Income Toggle ──────────────────────
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() { _isExpense = true; _kategori = 'Makan & Minum'; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                      color: _isExpense ? AppColors.expense : Colors.transparent,
                      width: 2,
                    )),
                  ),
                  child: Text('PENGELUARAN', textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isExpense ? AppColors.expense : AppColors.textMuted,
                      fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5)),
                ),
              )),
              Container(width: 1, height: 20, color: AppColors.divider),
              Expanded(child: GestureDetector(
                onTap: () => setState(() { _isExpense = false; _kategori = 'Gaji'; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                      color: !_isExpense ? AppColors.income : Colors.transparent,
                      width: 2,
                    )),
                  ),
                  child: Text('PEMASUKAN', textAlign: TextAlign.center,
                    style: TextStyle(
                      color: !_isExpense ? AppColors.income : AppColors.textMuted,
                      fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5)),
                ),
              )),
            ]),
            const SizedBox(height: 12),

            // ── Date & Wallet Row ─────────────────────────────
            Row(children: [
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(formatTanggalShort(_tanggal),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  const Text('💰', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(_walletName,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
                ]),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Amount Display ─────────────────────────────────
            Center(child: Column(children: [
              const Text('Jumlah', style: TextStyle(
                color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('IDR ', style: TextStyle(
                  color: _isExpense ? AppColors.expense : AppColors.income,
                  fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  formatAmount(_parseAmount()),
                  style: TextStyle(
                    color: _isExpense ? AppColors.expense : AppColors.income,
                    fontSize: 36, fontWeight: FontWeight.w800),
                ),
              ]),
            ])),
            const SizedBox(height: 12),

            // ── Description Field ──────────────────────────────
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Deskripsi (Opsional)', style: TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(
                  controller: _deskripsiCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'kopi',
                    hintStyle: const TextStyle(color: AppColors.textHint),
                    filled: true, fillColor: AppColors.bgElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => _deskripsi = v,
                )),
                const SizedBox(width: 8),
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_fix_high, color: AppColors.primary, size: 18),
                ),
              ]),
              const SizedBox(height: 4),
              const Text('✦ Otomatis kategorikan dari transaksi terakhir',
                style: TextStyle(color: AppColors.textHint, fontSize: 10)),
            ]),
            const SizedBox(height: 14),

            // ── Category Grid ──────────────────────────────────
            CategoryIconGrid(
              categories: categories,
              selectedCategory: _kategori,
              onSelected: (v) => setState(() => _kategori = v),
            ),
            const SizedBox(height: 14),

            // ── Type Tags (Need/Want/Saving) ───────────────────
            if (_isExpense) ...[
              const Text('TIPE', style: TextStyle(
                color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              TransactionTypeSelector(
                selected: _tipe,
                onSelected: (t) => setState(() => _tipe = _tipe == t ? null : t),
              ),
              const SizedBox(height: 8),
            ],
          ]),
        )),

        // ── Amount display above numpad ──────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: AppColors.numpadBg,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('= ${formatAmount(_parseAmount())}',
              style: const TextStyle(color: AppColors.textSecond, fontSize: 14)),
          ]),
        ),

        // ── Calculator Numpad ─────────────────────────────────
        CalcNumpad(
          onKey: _onNumKey,
          onDelete: _onDelete,
          onConfirm: _onConfirm,
          onEquals: () {},
        ),

        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
    );
  }
}
