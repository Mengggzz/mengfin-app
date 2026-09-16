import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';

class KazzScreen extends StatefulWidget {
  const KazzScreen({super.key});
  @override State<KazzScreen> createState() => _KazzScreenState();
}

class _KazzScreenState extends State<KazzScreen> {
  int _tabIndex = 0; // 0 = Dompet, 1 = Budget
  List<Akun> _wallets = [];
  List<Anggaran> _budgets = [];
  String _budgetPeriode = currentBulan();
  String _budgetFilter = 'Semua'; // Semua / Aktif
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getAkunList(),
        ApiService.getAnggaran(_budgetPeriode),
      ]);
      setState(() {
        _wallets = results[0] as List<Akun>;
        _budgets = results[1] as List<Anggaran>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  double get _totalSaldo => _wallets.fold(0.0, (s, a) => s + a.saldo);

  void _showAddBudgetModal({Anggaran? edit}) {
    String kategori = edit?.kategori ?? 'Makan & Minum';
    String batas = edit != null ? edit.batas.toStringAsFixed(0) : '';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(edit != null ? 'Edit Budget' : 'Buat Budget Baru',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          if (edit == null) ...[
            const Text('KATEGORI', style: TextStyle(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal,
              children: expenseCategories.map((k) =>
                GestureDetector(
                  onTap: () => ss(() => kategori = k.label),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: kategori == k.label ? Color(k.color).withOpacity(0.2) : AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kategori == k.label ? Color(k.color) : AppColors.glassBorder),
                    ),
                    child: Text('${k.icon} ${k.label}', style: TextStyle(
                      color: kategori == k.label ? Color(k.color) : AppColors.textMuted, fontSize: 12)),
                  ),
                )).toList())),
            const SizedBox(height: 16),
          ],

          const Text('BATAS ANGGARAN (Rp)', style: TextStyle(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: batas),
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '1.500.000', hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.bgElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary)),
            ),
            onChanged: (v) => batas = v,
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              final b = double.tryParse(batas.replaceAll(RegExp(r'\D'), '')) ?? 0;
              if (edit != null) { await ApiService.updateAnggaran(edit.id, b); }
              else { await ApiService.createAnggaran(kategori, b, _budgetPeriode); }
              Navigator.pop(context); _load();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: RefreshIndicator(
        color: AppColors.primary, backgroundColor: AppColors.bgCard,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          const SizedBox(height: 16),
          // ── Header ───────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Kazz', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
            Row(children: [
              _headerIcon(Icons.ios_share_outlined),
              const SizedBox(width: 8),
              _headerIcon(Icons.calendar_month_outlined),
              const SizedBox(width: 8),
              _headerIcon(Icons.tune),
            ]),
          ]),
          const SizedBox(height: 16),

          // ── Segment Tabs ─────────────────────────────────────
          SegmentedTab(
            tabs: const ['Dompet', 'Budget'],
            selectedIndex: _tabIndex,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else ...[
            if (_tabIndex == 0) _buildDompetTab()
            else _buildBudgetTab(),
          ],
        ]),
      )),
    );
  }

  Widget _headerIcon(IconData icon) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: Icon(icon, color: AppColors.textSecond, size: 18),
  );

  // ─── Dompet (Wallets) Tab ──────────────────────────────────
  Widget _buildDompetTab() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Saldo header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text('Saldo', style: TextStyle(
              color: AppColors.textSecond, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
          ]),
          Text('Rp ${formatAmount(_totalSaldo)}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 12),

      // Filter chips
      Row(children: [
        _filterChip('Semua', true),
        const SizedBox(width: 8),
        _filterChip('Cashflow', false),
        const Spacer(),
        Icon(Icons.tune, size: 18, color: AppColors.textMuted),
      ]),
      const SizedBox(height: 16),

      // Wallet cards grid
      if (_wallets.isEmpty)
        const Center(child: Padding(padding: EdgeInsets.only(top: 40),
          child: Text('Belum ada dompet', style: TextStyle(color: AppColors.textMuted))))
      else
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: _wallets.map((w) => KazzWalletCard(
            name: w.nama,
            balance: w.saldo,
            icon: w.ikon == 'cash' ? '💵' : '💰',
          )).toList(),
        ),
      const SizedBox(height: 12),

      // Add wallet card
      AddKazzCard(onTap: () {
        // TODO: Navigate to add wallet screen
      }),
      const SizedBox(height: 24),
    ]);
  }

  Widget _filterChip(String label, bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: active ? AppColors.primary.withOpacity(0.15) : AppColors.bgCard,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: active ? AppColors.primary : AppColors.glassBorder),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (active) ...[
        Container(width: 6, height: 6, decoration: const BoxDecoration(
          color: AppColors.primary, shape: BoxShape.circle)),
        const SizedBox(width: 6),
      ],
      Text(label, style: TextStyle(
        color: active ? AppColors.primary : AppColors.textMuted,
        fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  // ─── Budget Tab ─────────────────────────────────────────────
  Widget _buildBudgetTab() {
    final filteredBudgets = _budgetFilter == 'Aktif'
        ? _budgets.where((b) => b.persentase < 100).toList()
        : _budgets;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Filter: Semua / Aktif
      Row(children: [
        GestureDetector(
          onTap: () => setState(() => _budgetFilter = 'Semua'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _budgetFilter == 'Semua' ? AppColors.bgElevated : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _budgetFilter == 'Semua' ? AppColors.glassBorder : Colors.transparent),
            ),
            child: Text('Semua', style: TextStyle(
              color: _budgetFilter == 'Semua' ? AppColors.textPrimary : AppColors.textMuted,
              fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() => _budgetFilter = 'Aktif'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _budgetFilter == 'Aktif' ? AppColors.success.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _budgetFilter == 'Aktif' ? AppColors.success : Colors.transparent),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_budgetFilter == 'Aktif') ...[
                Container(width: 6, height: 6, decoration: const BoxDecoration(
                  color: AppColors.success, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text('Aktif', style: TextStyle(
                color: _budgetFilter == 'Aktif' ? AppColors.success : AppColors.textMuted,
                fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const Spacer(),
        Icon(Icons.tune, size: 18, color: AppColors.textMuted),
      ]),
      const SizedBox(height: 12),

      const Text(
        'Tetapkan batas bulanan untuk setiap kategori — dapat pengingat sebelum kebablasan.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
      ),
      const SizedBox(height: 16),

      // Budget list or guide
      if (filteredBudgets.isEmpty) ...[
        // How it works guide
        _buildGuideCard(),
      ] else ...[
        ...filteredBudgets.map((a) => _buildBudgetCard(a)),
      ],
      const SizedBox(height: 16),

      // Create budget button
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => _showAddBudgetModal(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('+ Buat budget baru',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      )),
      const SizedBox(height: 8),
      const Center(child: Text(
        'Budget bisa diedit, dijeda, atau dihapus kapan saja.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
      )),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildBudgetCard(Anggaran a) {
    final kat = getKategoriInfo(a.kategori);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(
                color: Color(kat.color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(kat.icon, style: const TextStyle(fontSize: 16)))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.kategori, style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              Row(children: [
                CurrencyText(a.terpakai, short: true, color: AppColors.textMuted, fontSize: 11),
                const Text(' / ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                CurrencyText(a.batas, short: true, color: AppColors.textMuted, fontSize: 11),
              ]),
            ]),
          ]),
          Row(children: [
            GestureDetector(
              onTap: () => _showAddBudgetModal(edit: a),
              child: Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.textMuted))),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () async {
                await ApiService.deleteAnggaran(a.id);
                _load();
              },
              child: Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline, size: 14, color: AppColors.danger))),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: AppProgressBar(value: a.persentase, height: 8)),
          const SizedBox(width: 8),
          Text('${a.persentase.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: a.persentase >= 90 ? AppColors.danger : a.persentase >= 70 ? AppColors.warning : AppColors.success)),
        ]),
      ]),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📊', style: TextStyle(fontSize: 28)),
        const SizedBox(height: 8),
        const Text('CARA KERJANYA', style: TextStyle(
          color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        _guideStep(1, 'Pilih yang ingin dipantau',
          'Pilih satu atau beberapa kantong dan kategori yang ingin kamu awasi.'),
        _guideStep(2, 'Tetapkan batas dan periode',
          'Bulanan, mingguan, custom — Kazz hitung pakainya hari demi hari.'),
        _guideStep(3, 'Dapat peringatan sebelum kebablasan',
          'Notifikasi berwarna saat capai 50%, 80%, dan over budget.'),
        _guideStep(4, 'Berlanjut otomatis setiap siklus',
          'Budget direset dan diulang setiap periode.'),
      ]),
    );
  }

  Widget _guideStep(int num, String title, String desc) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 24, height: 24,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text('$num', style: const TextStyle(
          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
      ])),
    ]),
  );
}
