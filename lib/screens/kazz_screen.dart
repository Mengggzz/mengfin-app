import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_events.dart';
import '../services/kazz_filter.dart';
import '../widgets/kazz_illustrations.dart';
import '../widgets/widgets.dart';
import 'tambah_kazz_screen.dart';

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

  // ── Filter & urutan dompet (menu Kazz → tab Dompet) ─────────────
  KazzFilter _walletFilter = KazzFilter.semua;
  KazzSort _sortMode = KazzSort.nameAZ;

  /// Saldo disembunyikan (ikon kunci di panel Saldo). Tap untuk lihat.
  bool _saldoTersembunyi = true;

  /// Titik acuan posisi menu urutkan.
  final GlobalKey _sortKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
    // Kazz baru dari layar Tambah Kazz langsung tampil tanpa refresh manual.
    AppEvents.instance.akun.addListener(_load);
  }

  @override
  void dispose() {
    AppEvents.instance.akun.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getAkunList(),
        ApiService.getAnggaran(_budgetPeriode),
      ]);
      if (!mounted) return;
      setState(() {
        _wallets = results[0] as List<Akun>;
        _budgets = results[1] as List<Anggaran>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  double get _totalSaldo => _wallets.fold(0.0, (s, a) => s + a.saldo);

  /// Dompet setelah difilter lalu diurutkan sesuai pilihan di menu sort.
  List<Akun> get _walletsTampil =>
      filterDanUrutkanKazz(_wallets, _walletFilter, _sortMode);

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
            style:  TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          if (edit == null) ...[
             Text('KATEGORI', style: TextStyle(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600)),
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

           Text('BATAS ANGGARAN (Rp)', style: TextStyle(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: batas),
            keyboardType: TextInputType.number,
            style:  TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '1.500.000', hintStyle:  TextStyle(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.bgElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide:  BorderSide(color: AppColors.primary)),
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
             Text('Kazz', style: TextStyle(
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
             Padding(padding: EdgeInsets.only(top: 80),
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
    final wallets = _walletsTampil;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Panel Saldo (garis putus-putus) ──────────────────────────
      DashedBox(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
             Text('Saldo', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _saldoTersembunyi = !_saldoTersembunyi),
              child: Icon(
                _saldoTersembunyi ? Icons.lock_outline : Icons.lock_open_outlined,
                size: 14, color: AppColors.textMuted),
            ),
          ]),
          Text(
            _saldoTersembunyi
                ? '••••••'
                : '${_totalSaldo < 0 ? '-' : ''}Rp ${formatAmount(_totalSaldo.abs())}',
            style: TextStyle(
              color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 14),

      // ── Filter chips + tombol urutkan ────────────────────────────
      Row(children: [
        _filterChip('Semua', _walletFilter == KazzFilter.semua,
          icon: Icons.check_circle,
          onTap: () => setState(() => _walletFilter = KazzFilter.semua)),
        const SizedBox(width: 8),
        _filterChip('Cashflow', _walletFilter == KazzFilter.cashflow,
          onTap: () => setState(() => _walletFilter = KazzFilter.cashflow)),
        const SizedBox(width: 8),
        _filterChip('Arsip', _walletFilter == KazzFilter.arsip,
          icon: Icons.inventory_2_outlined,
          onTap: () => setState(() => _walletFilter = KazzFilter.arsip)),
        const Spacer(),
        _sortButton(),
      ]),
      const SizedBox(height: 16),

      // ── Daftar dompet ────────────────────────────────────────────
      if (_wallets.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Text(
            _walletFilter == KazzFilter.semua
                ? 'Belum ada Kazz. Tambahkan yang pertama di bawah.'
                : 'Tidak ada Kazz untuk filter ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          )),
        )
      else
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: wallets.map(_buildWalletCard).toList(),
        ),
      const SizedBox(height: 12),

      // ── Kartu Tambah Kazz ────────────────────────────────────────
      AddKazzCard(
        compact: true,
        onTap: () => _bukaTambahKazz(),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildWalletCard(Akun w) {
    final jenis = KazzIllustration.normalisasiJenis(w.jenis);
    return KazzWalletCard(
      name: w.nama,
      balance: w.saldo,
      jenis: jenis,
      onTap: () => _showWalletDetail(w),
      onMenuTap: () => _showWalletMenu(w),
    );
  }

  /// Tombol urutkan — membuka menu seperti referensi (Name A-Z dst).
  Widget _sortButton() {
    return GestureDetector(
      onTap: _showSortMenu,
      child: Container(
        key: _sortKey,
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(Icons.sort_rounded, size: 18, color: AppColors.textPrimary),
      ),
    );
  }

  /// Menu urutan. Ditampilkan lewat showMenu supaya posisinya menempel
  /// tepat di bawah tombol sort, bukan di tengah layar.
  Future<void> _showSortMenu() async {
    final box = _sortKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final topLeft = box.localToGlobal(Offset.zero);
    final size = box.size;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final pilihan = await showMenu<KazzSort>(
      context: context,
      color: AppColors.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(topLeft.dx - 150, topLeft.dy + size.height + 4, 210, 0),
        Offset.zero & overlay.size,
      ),
      items: KazzSort.values.map((mode) => PopupMenuItem<KazzSort>(
        value: mode,
        height: 46,
        child: Row(children: [
          if (_sortMode == mode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
            ),
          Expanded(child: Text(mode.label, style: TextStyle(
            color: AppColors.textPrimary, fontSize: 14))),
        ]),
      )).toList(),
    );

    if (pilihan != null && mounted) setState(() => _sortMode = pilihan);
  }

  /// Menu tiga titik pada kartu dompet: ubah nama / saldo, atau hapus.
  Future<void> _showWalletMenu(Akun w) async {
    final aksi = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        ListTile(
          leading: KazzIllustration.forJenis(w.jenis, size: 28),
          title: Text(w.nama, style: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          subtitle: Text('${w.saldo < 0 ? '-' : ''}Rp ${formatAmount(w.saldo.abs())}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
        Divider(color: AppColors.divider, height: 1),
        _sheetAction(ctx, Icons.edit_outlined, 'Ubah saldo', 'edit'),
        _sheetAction(ctx, Icons.delete_outline, 'Hapus Kazz', 'hapus',
          color: AppColors.danger),
        const SizedBox(height: 8),
      ])),
    );

    if (!mounted || aksi == null) return;
    if (aksi == 'edit') await _showEditSaldoModal(w);
    if (aksi == 'hapus') await _hapusWallet(w);
  }

  Widget _sheetAction(BuildContext ctx, IconData icon, String label, String value,
      {Color? color}) =>
      ListTile(
        onTap: () => Navigator.pop(ctx, value),
        leading: Icon(icon, color: color ?? AppColors.textSecond, size: 20),
        title: Text(label, style: TextStyle(
          color: color ?? AppColors.textPrimary, fontSize: 14)),
      );

  Future<void> _showEditSaldoModal(Akun w) async {
    final ctrl = TextEditingController(text: w.saldo.toStringAsFixed(0));
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Ubah saldo ${w.nama}', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.bgElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              final baru = double.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
              Navigator.pop(ctx);
              try {
                await ApiService.updateAkunSaldo(w.id, baru);
                AppEvents.instance.akunBerubah();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Gagal menyimpan: $e')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Simpan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          )),
        ]),
      ),
    );
  }

  Future<void> _hapusWallet(Akun w) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus ${w.nama}?',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Kazz ini akan dihapus dari daftar dompetmu.',
          style: TextStyle(color: AppColors.textSecond, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: AppColors.textSecond))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(
              color: AppColors.danger, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (yakin != true) return;

    try {
      await ApiService.deleteAkun(w.id);
      AppEvents.instance.akunBerubah();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  /// Ketuk kartu → ringkasan singkat dompet.
  void _showWalletDetail(Akun w) {
    final jenis = KazzIllustration.normalisasiJenis(w.jenis);
    final label = kazzTipes
        .firstWhere((t) => t.key == jenis, orElse: () => kazzTipes.first)
        .nama;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Row(children: [
            KazzIllustration(jenis: jenis, size: 44),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(w.nama, style: TextStyle(
                color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ])),
          ]),
          const SizedBox(height: 18),
          DashedBox(child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Saldo', style: TextStyle(color: AppColors.textSecond, fontSize: 13)),
              Text('${w.saldo < 0 ? '-' : ''}Rp ${formatAmount(w.saldo.abs())}',
                style: TextStyle(
                  color: w.saldo < 0 ? AppColors.expense : AppColors.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w700)),
            ])),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }

  Future<void> _bukaTambahKazz() async {
    final ditambah = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TambahKazzScreen()),
    );
    if (ditambah == true) _load();
  }

  Widget _filterChip(String label, bool active, {IconData? icon, VoidCallback? onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.slateSoft : AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? AppColors.glassBorder : AppColors.glassBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 14,
                color: active ? AppColors.textPrimary : AppColors.textMuted),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(
              color: active ? AppColors.textPrimary : AppColors.textMuted,
              fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
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
                Container(width: 6, height: 6, decoration:  BoxDecoration(
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

       Text(
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
       Center(child: Text(
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
              Text(a.kategori, style:  TextStyle(
                color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              Row(children: [
                CurrencyText(a.terpakai, short: true, color: AppColors.textMuted, fontSize: 11),
                 Text(' / ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                CurrencyText(a.batas, short: true, color: AppColors.textMuted, fontSize: 11),
              ]),
            ]),
          ]),
          Row(children: [
            GestureDetector(
              onTap: () => _showAddBudgetModal(edit: a),
              child: Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(8)),
                child:  Icon(Icons.edit_outlined, size: 14, color: AppColors.textMuted))),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () async {
                await ApiService.deleteAnggaran(a.id);
                _load();
              },
              child: Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child:  Icon(Icons.delete_outline, size: 14, color: AppColors.danger))),
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
