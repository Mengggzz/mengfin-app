import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_events.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../services/update_service.dart';
import '../widgets/widgets.dart';
import '../widgets/update_dialog.dart';
import 'ai_screen.dart';
import 'anggaran_screen.dart';
import 'calendar_screen.dart';
import 'laporan_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  List<dynamic> _recentTx = [];
  bool _loading = true;
  bool _isOfflineData = false;
  bool _error = false;

  // Budget harian state
  double _budgetHarian = 0;
  double _pengeluaranHariIni = 0;
  List<double> _last7DaysSpending = [];
  int _overBudgetDays = 0;
  bool _budgetMinimized = false;
  int _budgetViewMode = 0; // 0 = grafik bar, 1 = rincian harian
  PageController? _insightPageCtrl;
  int _insightPage = 0;
  bool _hasUpdate = false; // penanda titik di ikon notifikasi

  // Kategori breakdown (untuk swipe Saldo vs Pengeluaran)
  List<Map<String, dynamic>> _kategoriBreakdown = [];

  @override
  void initState() {
    super.initState();
    _load();
    _autoCheckUpdate();
    // Data baru (hasil scan struk, input manual, voice, hapus) langsung
    // menyegarkan layar ini tanpa perlu pull-to-refresh.
    AppEvents.instance.transaksi.addListener(_onDataBerubah);
    AppEvents.instance.anggaran.addListener(_onDataBerubah);
  }

  void _onDataBerubah() {
    if (!mounted) return;
    _load();
  }

  /// Cek update saat app dibuka — hanya beri tahu, tidak memaksa.
  /// Diam total kalau sudah versi terbaru.
  Future<void> _autoCheckUpdate() async {
    try {
      final r = await UpdateService.instance.checkForUpdate();
      if (!mounted) return;
      setState(() => _hasUpdate = r.hasUpdate);
      if (r.hasUpdate) {
        await UpdateFlow.run(context);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    AppEvents.instance.transaksi.removeListener(_onDataBerubah);
    AppEvents.instance.anggaran.removeListener(_onDataBerubah);
    _insightPageCtrl?.dispose();
    super.dispose();
  }

  Future<void> _hapusTransaksi(dynamic tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title:  Text('Hapus Transaksi?', style: TextStyle(color: AppColors.textPrimary)),
        content:  Text('Tindakan ini tidak dapat dibatalkan.', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child:  Text('Batal', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child:  Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (tx.id != null) await ApiService.deleteTransaksi(tx.id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal: $e'), backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final results = await Future.wait([
        ApiService.getDashboard(),
        ApiService.getTransaksi(limit: 200),
      ]);
      final prefs = await SharedPreferences.getInstance();
      final savedBudget = prefs.getDouble('budget_harian') ?? 0;

      final allTx = results[1] as List;
      final now = DateTime.now();

      // Hitung pengeluaran hari ini
      double todaySpend = 0;
      final nowLocal = DateTime(now.year, now.month, now.day);
      
      for (final tx in allTx) {
        try {
          final txDateRaw = DateTime.parse(tx.tanggal).toLocal();
          final txDate = DateTime(txDateRaw.year, txDateRaw.month, txDateRaw.day);
          
          if (txDate.isAtSameMomentAs(nowLocal)) {
            if (tx.jenis == 'pengeluaran') todaySpend += tx.nominal;
          }
        } catch (_) {}
      }

      // Hitung 7 hari terakhir
      List<double> last7 = List.filled(7, 0);
      int overDays = 0;
      for (int i = 0; i < 7; i++) {
        final targetDay = now.subtract(Duration(days: 6 - i));
        final targetDate = DateTime(targetDay.year, targetDay.month, targetDay.day);
        
        double daySpend = 0;
        for (final tx in allTx) {
          try {
            final txDateRaw = DateTime.parse(tx.tanggal).toLocal();
            final txDate = DateTime(txDateRaw.year, txDateRaw.month, txDateRaw.day);
            
            if (txDate.isAtSameMomentAs(targetDate)) {
              if (tx.jenis == 'pengeluaran') daySpend += tx.nominal;
            }
          } catch (_) {}
        }
        last7[i] = daySpend;
        if (savedBudget > 0 && daySpend > savedBudget) overDays++;
      }

      // Hitung breakdown kategori pengeluaran (30 hari terakhir, untuk swipe)
      final cutoff = now.subtract(const Duration(days: 30));
      final katMap = <String, double>{};
      for (final tx in allTx) {
        if (tx.jenis != 'pengeluaran') continue;
        try {
          final txDateRaw = DateTime.parse(tx.tanggal).toLocal();
          if (txDateRaw.isBefore(cutoff)) continue;
          final k = (tx.kategori ?? 'Lainnya').toString();
          katMap[k] = (katMap[k] ?? 0) + tx.nominal;
        } catch (_) {}
      }
      final katList = katMap.entries
          .map((e) => {'kategori': e.key, 'total': e.value})
          .toList()
        ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

      setState(() {
        _data = results[0] as DashboardData;
        _recentTx = allTx.take(10).toList();
        _kategoriBreakdown = katList;
        _loading = false;
        _isOfflineData = false;
        _budgetHarian = savedBudget;
        _pengeluaranHariIni = todaySpend;
        _last7DaysSpending = last7;
        _overBudgetDays = overDays;
      });
    } catch (e, st) {
      print('DEBUG Dashboard Load Error: $e');
      print('Stacktrace: $st');
      if (e.toString().contains('unauthorized')) {
        await AuthService.instance.signOut();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      if (kIsWeb) {
        setState(() { _loading = false; _error = true; });
        return;
      }
      try {
        final bulan = currentBulan();
        final localStats = await LocalDb.getDashboardLocal(bulan);
        final recentTx = await LocalDb.getTransaksi(limit: 10);
        final saldo = localStats['saldo'] ?? 0;
        final pemasukan = localStats['pemasukan'] ?? 0;
        final pengeluaran = localStats['pengeluaran'] ?? 0;
        setState(() {
          _data = DashboardData(
            saldoTotal: saldo,
            pemasukanBulanIni: pemasukan,
            pengeluaranBulanIni: pengeluaran,
            bulanIni: bulan,
            health: HealthScore(score: 0, status: 'Offline', warna: '#606080', pesan: 'Data lokal'),
            rataHarian: pengeluaran > 0 ? pengeluaran / DateTime.now().day : 0,
            mingguIniPengeluaran: 0,
            kenaikanPersen: 0,
            kategoriTerbesar: '-',
            mingguPeriode: '',
            prediksiSaldoAkhir: saldo,
            sisaHari: DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day - DateTime.now().day,
            prediksiStatus: 'aman',
          );
          _recentTx = recentTx;
          _loading = false;
          _isOfflineData = true;
        });
      } catch (_) {
        setState(() { _loading = false; _error = true; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
        ?  Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _error || _data == null
          ? _buildErrorState()
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.bgCard,
              onRefresh: _load,
              child: CustomScrollView(slivers: [
                if (_isOfflineData) _buildOfflineBanner(),
                SliverToBoxAdapter(child: _buildContent()),
              ]),
            ),
    );
  }

  Widget _buildErrorState() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
       Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 48),
      const SizedBox(height: 16),
       Text('Gagal memuat data', style: TextStyle(
        color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
       Text('Periksa koneksi internet', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Coba Lagi'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    ],
  ));

  Widget _buildOfflineBanner() => SliverToBoxAdapter(child: Container(
    padding: const EdgeInsets.fromLTRB(16, 52, 16, 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child:  Row(children: [
        Icon(Icons.info_outline, size: 14, color: AppColors.warning),
        SizedBox(width: 8),
        Text('Menampilkan data lokal · Refresh saat online',
          style: TextStyle(color: AppColors.warning, fontSize: 11)),
      ]),
    ),
  ));

  Widget _buildContent() {
    final d = _data!;
    final totalFlow = d.pemasukanBulanIni + d.pengeluaranBulanIni;
    final saldoPersen = totalFlow > 0 ? (d.saldoTotal.abs() / totalFlow * 100).clamp(0.0, 100.0) : 0.0;
    final pengeluaranPersen = totalFlow > 0 ? (d.pengeluaranBulanIni / totalFlow * 100) : 0.0;

    // Group recent transactions by date
    final groupedTx = <String, List<dynamic>>{};
    for (final tx in _recentTx) {
      final date = tx.tanggal.length > 10 ? tx.tanggal.substring(0, 10) : tx.tanggal;
      groupedTx.putIfAbsent(date, () => []).add(tx);
    }

    return SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────
        // 5. Icon kamera → kalender
        // 4. Icon jam → laporan (bar_chart)
        // 3. Icon notifikasi → update discord
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
           Text('Home', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
          Row(children: [
            _headerIcon(Icons.calendar_today_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()))),
            const SizedBox(width: 8),
            _headerIcon(Icons.bar_chart_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaporanScreen()))),
            const SizedBox(width: 8),
            _notificationIcon(),
          ]),
        ]),
        const SizedBox(height: 16),

        // ── Wallet Card (Dompet Saya) ───────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                 Text('Dompet Saya', style: TextStyle(
                  color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                 Icon(Icons.lock_outline, size: 13, color: AppColors.textMuted),
              ]),
              const SizedBox(height: 6),
              Text(
                '${d.saldoTotal < 0 ? '-' : ''}Rp ${formatAmount(d.saldoTotal.abs())}',
                style: TextStyle(
                  color: d.saldoTotal < 0 ? AppColors.expense : AppColors.income,
                  fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
               Text('1 dompet · ketuk untuk kelola',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child:  Text('Dompet Utama', style: TextStyle(
                  color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
              ),
            ]),
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(child: Text('💰', style: TextStyle(fontSize: 28))),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Quick Actions (1. Analytics dihapus, digabung budget harian) ───
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            QuickActionButton(
              icon: Icons.mic,
              label: 'Voice Text',
              iconColor: AppColors.primary,
              onTap: () async {
                final saved = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => const VoiceToTextDialog(),
                );
                if (saved == true && mounted) _load();
              },
            ),
            const SizedBox(width: 8),
            QuickActionButton(
              icon: Icons.auto_awesome,
              label: 'Kazz AI',
              iconColor: AppColors.primary,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiScreen())),
            ),
            const SizedBox(width: 8),
            QuickActionButton(
              icon: Icons.camera_alt,
              label: 'Scan Struk',
              iconColor: AppColors.expense,
              onTap: () async {
                final saved = await Navigator.push<bool>(
                  context, MaterialPageRoute(builder: (_) => const ScanScreen()));
                if (saved == true && mounted) _load();
              },
            ),
            const SizedBox(width: 8),
            QuickActionButton(
              icon: Icons.pie_chart,
              label: 'Budget',
              iconColor: AppColors.expense,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnggaranScreen())),
            ),
            const SizedBox(width: 8),
            // 6. Icon tune → pengaturan beranda
            GestureDetector(
              onTap: () => _showBerandaSettings(),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child:  Icon(Icons.tune, size: 18, color: AppColors.textMuted),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Insight Carousel: Saldo vs Pengeluaran + Kategori (swipe) ──
        _buildInsightCarousel(d, saldoPersen, pengeluaranPersen),
        const SizedBox(height: 12),

        // ── Budget Harian (2. diperbaiki fungsinya, 1. analytics digabung) ─
        _buildBudgetHarianCard(),
        const SizedBox(height: 20),

        // ── Transactions Header ──────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
           Text('Transaksi', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child:  Row(mainAxisSize: MainAxisSize.min, children: [
                Text('7 hari terakhir', style: TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textMuted),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Transaction List by Date ────────────────────────────
        if (_recentTx.isEmpty)
           Center(child: Padding(padding: EdgeInsets.all(20),
            child: Text('Belum ada transaksi', style: TextStyle(color: AppColors.textMuted))))
        else
          ...groupedTx.entries.map((entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _isToday(entry.key) ? 'Hari ini, ${formatTanggalShort(entry.key)}' : formatTanggalShort(entry.key),
                  style:  TextStyle(
                    color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              ...entry.value.map((tx) => TransaksiTile(
                tx: tx,
                onDelete: () => _hapusTransaksi(tx),
              )),
            ],
          )),
      ]),
    ));
  }

  // ══════════════════════════════════════════════════════════════
  // 2. BUDGET HARIAN — Full widget dengan chart & progress bar
  // ══════════════════════════════════════════════════════════════
  String _compactLabel(double v) {
    if (v >= 1000000000) return '${(v / 1000000000).toStringAsFixed(v >= 10000000000 ? 0 : 1)}M';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v >= 10000000 ? 0 : 1)}jt';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}rb';
    if (v > 0) return v.toStringAsFixed(0);
    return '0';
  }

  Widget _buildBudgetHarianCard() {
    final sisa = _budgetHarian - _pengeluaranHariIni;
    final totalWeek = _last7DaysSpending.fold(0.0, (a, b) => a + b);
    final rataRata = totalWeek / 7;
    final progress = _budgetHarian > 0 ? (_pengeluaranHariIni / _budgetHarian).clamp(0.0, 1.0) : 0.0;
    final isOverToday = _budgetHarian > 0 && _pengeluaranHariIni > _budgetHarian;
    // max untuk skala chart — pakai budget sebagai referensi, clamp outlier biar bar lain tetap kelihatan
    double rawMax = _last7DaysSpending.isEmpty ? 0 : _last7DaysSpending.reduce((a, b) => a > b ? a : b);
    if (_budgetHarian > 0 && _budgetHarian > rawMax) rawMax = _budgetHarian;
    // jika ada outlier > 3x budget, clamp max ke 1.5x budget biar chart tetap readable (bar outlier tetap full)
    double maxChart = rawMax;
    if (_budgetHarian > 0 && rawMax > _budgetHarian * 3) maxChart = _budgetHarian * 1.5;
    if (maxChart <= 0) maxChart = 1;

    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header + toggle minimize/maximize
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
           Text('Budget Harian', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _editBudgetHarian(),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(6)),
              child:  Icon(Icons.edit_outlined, size: 12, color: AppColors.textMuted),
            ),
          ),
        ]),
        Row(children: [
          if (_budgetHarian > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgElevated, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text('Rp ${formatAmount(_budgetHarian)}/hari',
                style:  TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
            )
          else
             Text('Belum diatur', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _budgetMinimized = !_budgetMinimized),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(6)),
              child: Icon(_budgetMinimized ? Icons.expand_more : Icons.expand_less,
                size: 14, color: AppColors.textMuted),
            ),
          ),
        ]),
      ]),

      // Minimized: ringkasan 1 baris
      if (_budgetMinimized && _budgetHarian > 0) ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.bgElevated,
                valueColor: AlwaysStoppedAnimation(
                  progress >= 1.0 ? AppColors.chartOver :
                  progress >= 0.7 ? AppColors.chartWarn : AppColors.chartSafe),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('Rp ${formatAmount(sisa.abs())} ${sisa >= 0 ? 'sisa' : 'over'}',
            style: TextStyle(
              color: sisa >= 0 ? AppColors.income : AppColors.expense,
              fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ],

      // Mode tabs (Grafik | Rincian) — hanya saat expanded
      if (!_budgetMinimized && _budgetHarian > 0) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.bgElevated, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _budgetModeTab('Grafik', 0),
            _budgetModeTab('Rincian', 1),
          ]),
        ),
      ],

      if (!_budgetMinimized && _budgetHarian > 0) ...[
        const SizedBox(height: 12),
        // Status sisa — lebih presisi, ada icon
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: sisa >= 0 ? AppColors.income.withOpacity(0.10) : AppColors.expense.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: (sisa >= 0 ? AppColors.income : AppColors.expense).withOpacity(0.18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(sisa >= 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              size: 14, color: sisa >= 0 ? AppColors.income : AppColors.expense),
            const SizedBox(width: 6),
            Text(
              sisa >= 0
                ? 'Sisa Rp ${formatAmount(sisa)} · hari ini'
                : 'Over Rp ${formatAmount(sisa.abs())} · hari ini',
              style: TextStyle(
                color: sisa >= 0 ? AppColors.income : AppColors.expense,
                fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        // Progress bar + label persen
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: AppColors.bgElevated,
                valueColor: AlwaysStoppedAnimation(
                  progress >= 1.0 ? AppColors.chartOver :
                  progress >= 0.7 ? AppColors.chartWarn : AppColors.chartSafe),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: progress >= 1.0 ? AppColors.chartOver
                : progress >= 0.7 ? AppColors.chartWarn : AppColors.textMuted,
              fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        if (_budgetViewMode == 0) ...[
        // Bar chart 7 hari — rapih + budget line + tooltip
        SizedBox(
          height: 128,
          child: LayoutBuilder(builder: (ctx, c) {
            // posisi garis budget dari bawah (dalam 90px area bar + 22px label)
            final budgetH = (_budgetHarian / maxChart * 90).clamp(0.0, 90.0);
            return Stack(children: [
              // grid lines tipis
              Positioned.fill(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(height: 1, color: AppColors.textMuted.withOpacity(0.06)),
                const Spacer(),
                Container(height: 1, color: AppColors.textMuted.withOpacity(0.06)),
                const Spacer(),
                Container(height: 1, color: AppColors.textMuted.withOpacity(0.06)),
                const SizedBox(height: 18), // ruang label hari
              ])),
              // garis budget dashed (tanpa label — label pindah ke strip atas
              // supaya tidak pernah menutupi bar hari ini di kolom kanan)
              if (_budgetHarian > 0)
                Positioned(
                  left: 0, right: 0, bottom: 18 + budgetH,
                  child: CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DashedLinePainter(AppColors.accent.withOpacity(0.7)),
                  ),
                ),
              // Keterangan garis budget — strip di atas grafik, selalu bebas
              // dari bar karena tinggi bar dibatasi di bawah strip ini.
              if (_budgetHarian > 0)
                Positioned(
                  top: 0, right: 0,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CustomPaint(
                      size: const Size(14, 1),
                      painter: _DashedLinePainter(AppColors.accent),
                    ),
                    const SizedBox(width: 4),
                    Text('budget ${_compactLabel(_budgetHarian)}',
                      style:  TextStyle(
                        color: AppColors.accent, fontSize: 8.5,
                        fontWeight: FontWeight.w700)),
                  ]),
                ),
              // bars — diberi jarak atas supaya tidak menyentuh strip label
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final day = now.subtract(Duration(days: 6 - i));
                  final val = i < _last7DaysSpending.length ? _last7DaysSpending[i] : 0.0;
                  final isToday = day.year == todayKey.year && day.month == todayKey.month && day.day == todayKey.day;
                  final isOver = _budgetHarian > 0 && val > _budgetHarian;
                  final isClamped = _budgetHarian > 0 && val > maxChart;
                  // tinggi bar: outlier yang di-clamp tetap full 90
                  final barH = isClamped ? 90.0 : (maxChart > 0 ? (val / maxChart * 90).clamp(0.0, 90.0) : 0.0);
                  final showLabel = val > 0;
                  return Expanded(child: GestureDetector(
                    onTap: val > 0 ? () => _showDayDetail(day) : null,
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      // dot over indicator
                      SizedBox(
                        height: 12,
                        child: isOver
                          ? Container(width: 6, height: 6, decoration:  BoxDecoration(color: AppColors.chartOver, shape: BoxShape.circle))
                          : const SizedBox(),
                      ),
                      // value label — compact, tidak numpuk
                      SizedBox(
                        height: 12,
                        child: showLabel
                          ? Text(_compactLabel(val),
                              style: TextStyle(
                                color: isOver ? AppColors.chartOver : AppColors.textMuted,
                                fontSize: 7.5, fontWeight: isToday ? FontWeight.w700 : FontWeight.w500))
                          : const SizedBox(),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 22,
                        height: barH < 3 && val > 0 ? 3 : barH,
                        decoration: BoxDecoration(
                          gradient: val == 0 ? null : LinearGradient(
                            colors: AppColors.barGradientFor(
                              _budgetHarian > 0 ? val / _budgetHarian : 0),
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter),
                          color: val == 0 ? AppColors.bgElevated : null,
                          borderRadius: BorderRadius.circular(6),
                          border: isToday
                            ? Border.all(color: AppColors.textPrimary.withOpacity(0.45), width: 1)
                            : null,
                          boxShadow: isToday && val > 0
                            ? [BoxShadow(color: AppColors.chartSafe.withOpacity(0.22), blurRadius: 6, offset: const Offset(0, 2))]
                            : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: isToday
                          ? BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))
                          : null,
                        child: Text(dayNames[(day.weekday - 1) % 7],
                          style: TextStyle(
                            color: isToday ? Colors.white : AppColors.textMuted,
                            fontSize: 9, fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    ]),
                  ));
                }),
              ),
              ),
            ]);
          }),
        ),
        ], // end _budgetViewMode == 0
        if (_budgetViewMode == 1) ...[
          // Rincian harian — mobile friendly list 7 hari
          ...List.generate(7, (i) {
            final day = now.subtract(Duration(days: 6 - i));
            final val = i < _last7DaysSpending.length ? _last7DaysSpending[i] : 0.0;
            final isToday = day.year == todayKey.year && day.month == todayKey.month && day.day == todayKey.day;
            final isOver = _budgetHarian > 0 && val > _budgetHarian;
            final rowProgress = _budgetHarian > 0 ? (val / _budgetHarian).clamp(0.0, 1.0) : 0.0;
            return GestureDetector(
              onTap: () => _showDayDetail(day),
              child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isToday ? AppColors.primary.withOpacity(0.08) : AppColors.bgElevated.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isToday
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.textMuted.withOpacity(0.08)),
              ),
              child: Row(children: [
                Container(
                  width: 34,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    gradient: isToday ? const LinearGradient(colors: AppColors.gradientPrimary) : null,
                    color: isToday ? null : AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(6)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(dayNames[(day.weekday - 1) % 7],
                      style: TextStyle(color: isToday ? Colors.white : AppColors.textMuted,
                        fontSize: 9, fontWeight: FontWeight.w700)),
                    Text('${day.day}',
                      style: TextStyle(color: isToday ? Colors.white : AppColors.textPrimary,
                        fontSize: 12, fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(isToday ? 'Hari ini' : (isOver ? 'Over budget' : 'Dalam budget'),
                      style: TextStyle(
                        color: isOver ? AppColors.chartOver : AppColors.textSecond,
                        fontSize: 10, fontWeight: FontWeight.w600)),
                    Text('Rp ${formatAmount(val)}',
                      style: TextStyle(
                        color: isOver ? AppColors.chartOver : AppColors.textPrimary,
                        fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: rowProgress, minHeight: 4,
                      backgroundColor: AppColors.bgElevated,
                      valueColor: AlwaysStoppedAnimation(
                        AppColors.barColorFor(
                          _budgetHarian > 0 ? val / _budgetHarian : 0)),
                    ),
                  ),
                ])),
                const SizedBox(width: 6),
                 Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
              ]),
            ));
          }),
        ],
        const SizedBox(height: 12),
        Divider(height: 1, color: AppColors.textMuted.withOpacity(0.08)),
        const SizedBox(height: 10),
        // Statistik bawah — compact & presisi
        Row(children: [
          Expanded(child: _budgetStat('Rata-rata', 'Rp ${_compactLabel(rataRata)}')),
          Container(width: 1, height: 28, color: AppColors.textMuted.withOpacity(0.08)),
          Expanded(child: _budgetStat('Total 7 hari', 'Rp ${_compactLabel(totalWeek)}')),
          Container(width: 1, height: 28, color: AppColors.textMuted.withOpacity(0.08)),
          Expanded(child: _budgetStat('Over', '$_overBudgetDays hari',
            valueColor: _overBudgetDays > 0 ? AppColors.expense : null)),
        ]),
        if (isOverToday) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.expense.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.expense.withOpacity(0.18)),
            ),
            child:  Row(children: [
              Icon(Icons.error_outline, size: 13, color: AppColors.expense),
              SizedBox(width: 6),
              Expanded(child: Text('Hari ini sudah melebihi budget harian',
                style: TextStyle(color: AppColors.expense, fontSize: 11, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ] else ...[
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _editBudgetHarian(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child:  Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, color: AppColors.primary, size: 18),
              SizedBox(width: 6),
              Text('Atur budget harian', style: TextStyle(
                color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ],
    ]));
  }

  Widget _budgetModeTab(String label, int mode) {
    final active = _budgetViewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _budgetViewMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(
          color: active ? Colors.white : AppColors.textMuted,
          fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _budgetStat(String label, String value, {Color? valueColor}) => Column(children: [
    Text(label, style:  TextStyle(color: AppColors.textMuted, fontSize: 10)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(
      color: valueColor ?? AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);

  /// Buka kalender minimalis 7 hari terakhir + detail transaksi hari terpilih.
  Future<void> _showDayDetail(DateTime day) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DayDetailSheet(
        initialDay: day,
        last7: _last7DaysSpending,
        budgetHarian: _budgetHarian,
      ),
    );
    if (mounted) _load();
  }

  // ══════════════════════════════════════════════════════════════
  // 2. Edit Budget Harian dialog
  // ══════════════════════════════════════════════════════════════
  Future<void> _editBudgetHarian() async {
    final controller = TextEditingController(
      text: _budgetHarian > 0 ? _budgetHarian.toStringAsFixed(0) : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:  Text('Atur Budget Harian', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
           Text('Masukkan batas pengeluaran per hari',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style:  TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle:  TextStyle(color: AppColors.textMuted, fontSize: 16),
              hintText: '20000',
              hintStyle:  TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.bgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:  Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0;
              Navigator.pop(ctx, val);
            },
            child:  Text('Simpan', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result >= 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('budget_harian', result);
      _load(); // Reload data
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 3. Ikon notifikasi → beri tahu update terbaru dari GitHub
  //    (terintegrasi repo; kalau sudah terbaru, bilang sudah terbaru,
  //     dan tidak pernah memaksa user untuk update)
  // ══════════════════════════════════════════════════════════════
  Widget _notificationIcon() => GestureDetector(
    onTap: _checkUpdateManual,
    child: Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child:  Icon(Icons.notifications_outlined,
          color: AppColors.textSecond, size: 18),
      ),
      if (_hasUpdate)
        Positioned(
          right: -1, top: -1,
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: AppColors.expense,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bg, width: 1.5),
            ),
          ),
        ),
    ]),
  );

  Future<void> _checkUpdateManual() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content:  Row(children: [
          SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
          SizedBox(width: 16),
          Text('Memeriksa update...', style: TextStyle(color: AppColors.textSecond, fontSize: 14)),
        ]),
      ),
    );

    try {
      UpdateService.instance.resetCheck();
      final result = await UpdateService.instance.checkForUpdate();
      if (!mounted) return;
      Navigator.pop(context); // tutup loading
      if (!mounted) return;

      setState(() => _hasUpdate = result.hasUpdate);

      if (result.hasUpdate && result.release != null) {
        await UpdateDialog.show(context, result);
      } else {
        await InfoDialog.show(
          context,
          unknownCurrent: result.unknownCurrent,
          latestTag: result.latestTag,
          currentTag: result.currentTag,
          error: result.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal cek update: $e'),
          backgroundColor: AppColors.expense),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 6. Pengaturan Beranda (icon tune)
  // ══════════════════════════════════════════════════════════════
  void _showBerandaSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
           Text('Pengaturan Beranda', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
           Text('Kelola tampilan dan widget di halaman utama',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 20),
          _settingsTile(Icons.pie_chart_outline, 'Budget Harian', 'Atur batas pengeluaran harian',
            onTap: () { Navigator.pop(ctx); _editBudgetHarian(); }),
          _settingsTile(Icons.palette_outlined, 'Tampilan Kazz', 'Pilih dompet yang tampil di beranda',
            onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SettingsScreen(page: SettingsPage.kazzUtama))); }),
          _settingsTile(Icons.notifications_active_outlined, 'Auto-Notifikasi', 'Catat otomatis dari notifikasi',
            onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SettingsScreen(page: SettingsPage.autoNotif))); }),
        ]),
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) =>
    ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style:  TextStyle(
        color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style:  TextStyle(
        color: AppColors.textMuted, fontSize: 11)),
      trailing:  Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );

  // ── Helpers ──────────────────────────────────────────────────
  bool _isToday(String dateStr) {
    final today = DateTime.now();
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    return date.year == today.year && date.month == today.month && date.day == today.day;
  }

  Widget _headerIcon(IconData icon, {VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Icon(icon, color: AppColors.textSecond, size: 18),
    ),
  );

  // ══════════════════════════════════════════════════════════════
  // SWIPE CAROUSEL — Saldo vs Pengeluaran + Kategori pengeluaran
  // ══════════════════════════════════════════════════════════════
  Widget _buildInsightCarousel(DashboardData d, double saldoPersen, double pengeluaranPersen) {
    final kat = _kategoriBreakdown.take(4).toList();
    final pageCount = 1 + (kat.isEmpty ? 1 : kat.length);
    if (_insightPage >= pageCount) _insightPage = pageCount - 1;
    _insightPageCtrl ??= PageController();

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header + dots indicator
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            _insightPage == 0 ? 'Saldo vs Pengeluaran' : 'Kategori Pengeluaran',
            style:  TextStyle(color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          _carouselDots(pageCount),
        ]),
        Text(_insightPage == 0 ? 'Bulan ini' : '30 hari terakhir',
          style:  TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: PageView(
            controller: _insightPageCtrl,
            onPageChanged: (i) => setState(() => _insightPage = i),
            children: [
              _saldoPage(d, saldoPersen, pengeluaranPersen),
              if (kat.isEmpty)
                _emptyKategoriPage()
              else
                ...kat.map((k) => _kategoriPage(k, d)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _carouselDots(int count) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(count, (i) {
      final active = i == _insightPage;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(left: 4),
        height: 6,
        width: active ? 16 : 6,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.textMuted.withOpacity(0.35),
          borderRadius: BorderRadius.circular(99),
        ),
      );
    }),
  );

  // Page 0 — donut saldo vs pengeluaran
  Widget _saldoPage(DashboardData d, double saldoPersen, double pengeluaranPersen) {
    return Row(children: [
      SizedBox(
        width: 100, height: 100,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            sections: [
              PieChartSectionData(
                value: saldoPersen > 0 ? saldoPersen : 0.1,
                color: AppColors.income, radius: 13, showTitle: false),
              PieChartSectionData(
                value: pengeluaranPersen > 0 ? pengeluaranPersen : 0.1,
                color: AppColors.expense, radius: 13, showTitle: false),
            ],
            centerSpaceRadius: 31, sectionsSpace: 2, startDegreeOffset: -90,
          )),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${saldoPersen.toStringAsFixed(0)}%',
              style:  TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
             Text('Saldo', style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
          ]),
        ]),
      ),
      const SizedBox(width: 20),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _chartLegend('Saldo', '${saldoPersen.toStringAsFixed(0)}%', '', AppColors.income),
        const SizedBox(height: 8),
        _chartLegend('Pengeluaran', '${pengeluaranPersen.toStringAsFixed(0)}%',
          'Rp ${formatAmount(d.pengeluaranBulanIni)}', AppColors.expense),
        if (d.pengeluaranBulanIni > d.saldoTotal.abs() && d.saldoTotal < 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child:  Row(children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.warning),
              SizedBox(width: 5),
              Expanded(child: Text('Pengeluaran melebihi saldo',
                style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ])),
    ]);
  }

  // Page kategori — donut % share + insight strip
  Widget _kategoriPage(Map<String, dynamic> k, DashboardData d) {
    final total = _kategoriBreakdown.fold(0.0, (s, e) => s + (e['total'] as double));
    final val = k['total'] as double;
    final pct = total > 0 ? (val / total * 100) : 0.0;
    final info = getKategoriInfo(k['kategori'] as String);
    final color = Color(info.color);
    final topName = _kategoriBreakdown.isNotEmpty ? _kategoriBreakdown.first['kategori'] as String : '-';
    final topPct = total > 0
        ? ((_kategoriBreakdown.first['total'] as double) / total * 100) : 0.0;

    return Row(children: [
      SizedBox(
        width: 100, height: 100,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            sections: [
              PieChartSectionData(value: pct > 0 ? pct : 0.1, color: color, radius: 13, showTitle: false),
              PieChartSectionData(
                value: (100 - pct) > 0 ? (100 - pct) : 0.1,
                color: AppColors.bgElevated, radius: 13, showTitle: false),
            ],
            centerSpaceRadius: 31, sectionsSpace: 2, startDegreeOffset: -90,
          )),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${pct.toStringAsFixed(0)}%',
              style:  TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
            Text(info.icon, style: const TextStyle(fontSize: 11)),
          ]),
        ]),
      ),
      const SizedBox(width: 20),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(info.icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(child: Text(k['kategori'] as String,
            style:  TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Text('Rp ${formatAmount(val)}',
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.income.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8)),
          child: Text('$topName (${topPct.toStringAsFixed(0)}%) mendominasi pengeluaran',
            style:  TextStyle(color: AppColors.income, fontSize: 9.5, fontWeight: FontWeight.w600),
            maxLines: 2),
        ),
      ])),
    ]);
  }

  Widget _emptyKategoriPage() =>  Center(child: Text(
    'Belum ada data kategori',
    style: TextStyle(color: AppColors.textMuted, fontSize: 12)));

  Widget _chartLegend(String label, String persen, String amount, Color color) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(
      color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(label, style:  TextStyle(color: AppColors.textSecond, fontSize: 12)),
    const Spacer(),
    Text(persen, style:  TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
    if (amount.isNotEmpty) ...[
      const SizedBox(width: 6),
      Text(amount, style:  TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ],
  ]);
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════════
// Kalender 7 hari terakhir — minimalis, tapi detail transaksi per hari
// ══════════════════════════════════════════════════════════════════════════
class _DayDetailSheet extends StatefulWidget {
  final DateTime initialDay;
  final List<double> last7;
  final double budgetHarian;

  const _DayDetailSheet({
    required this.initialDay,
    required this.last7,
    required this.budgetHarian,
  });

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  late DateTime _selected;
  List<dynamic> _txs = [];
  bool _loading = true;
  bool _error = false;

  static const _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  void initState() {
    super.initState();
    _selected = DateTime(widget.initialDay.year, widget.initialDay.month, widget.initialDay.day);
    _load();
    AppEvents.instance.transaksi.addListener(_load);
  }

  @override
  void dispose() {
    AppEvents.instance.transaksi.removeListener(_load);
    super.dispose();
  }

  /// 7 tanggal terakhir, index 0 = 6 hari lalu (sama dengan _last7DaysSpending).
  List<DateTime> get _days {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final txs = await ApiService.getTransaksi(limit: 500);
      if (!mounted) return;
      setState(() { _txs = txs; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  String get _key =>
      '${_selected.year}-${_selected.month.toString().padLeft(2, '0')}-${_selected.day.toString().padLeft(2, '0')}';

  List<dynamic> get _dayTx => _txs.where((tx) {
    final t = (tx.tanggal ?? '').toString();
    return t.startsWith(_key);
  }).toList();

  double get _daySpend => _dayTx
      .where((t) => t.jenis == 'pengeluaran')
      .fold(0.0, (s, t) => s + (t.nominal as num).toDouble());

  double get _dayIncome => _dayTx
      .where((t) => t.jenis == 'pemasukan')
      .fold(0.0, (s, t) => s + (t.nominal as num).toDouble());

  double _spendFor(DateTime d) {
    final idx = _days.indexWhere((x) =>
      x.year == d.year && x.month == d.month && x.day == d.day);
    if (idx < 0 || idx >= widget.last7.length) return 0;
    return widget.last7[idx];
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.82;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration:  BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.textMuted.withOpacity(0.35),
            borderRadius: BorderRadius.circular(2)),
        ),

        // Judul
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
             Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
             Text('7 Hari Terakhir', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child:  Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // Strip kalender 7 hari
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = _days[i];
              final spend = _spendFor(d);
              final isSel = d.year == _selected.year &&
                  d.month == _selected.month && d.day == _selected.day;
              final isToday = i == 6;
              final ratio = widget.budgetHarian > 0 ? spend / widget.budgetHarian : 0.0;
              final barColor = AppColors.barColorFor(ratio);

              return GestureDetector(
                onTap: () => setState(() => _selected = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSel
                      ? const LinearGradient(colors: AppColors.gradientPrimary,
                          begin: Alignment.topCenter, end: Alignment.bottomCenter)
                      : null,
                    color: isSel ? null : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? AppColors.primary
                        : (isToday ? AppColors.primary.withOpacity(0.4) : AppColors.glassBorder),
                      width: isSel ? 1.4 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_dayNames[(d.weekday - 1) % 7], style: TextStyle(
                      color: isSel ? Colors.white70 : AppColors.textMuted,
                      fontSize: 9.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('${d.day}', style: TextStyle(
                      color: isSel ? Colors.white : AppColors.textPrimary,
                      fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    // indikator pengeluaran
                    Container(
                      width: 26, height: 3,
                      decoration: BoxDecoration(
                        color: spend > 0
                          ? (isSel ? Colors.white : barColor)
                          : AppColors.textMuted.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2)),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Ringkasan hari terpilih
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(formatTanggal(_key), style:  TextStyle(
                color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('${_dayTx.length} transaksi', style:  TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('-Rp ${formatAmount(_daySpend)}', style:  TextStyle(
                color: AppColors.expense, fontSize: 13, fontWeight: FontWeight.w700)),
              if (_dayIncome > 0) ...[
                const SizedBox(height: 3),
                Text('+Rp ${formatAmount(_dayIncome)}', style:  TextStyle(
                  color: AppColors.income, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ]),
          ]),
        ),

        // Status budget harian untuk hari itu
        if (widget.budgetHarian > 0) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (_daySpend / widget.budgetHarian).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: AppColors.bgElevated,
                  valueColor: AlwaysStoppedAnimation(
                    AppColors.barColorFor(_daySpend / widget.budgetHarian)),
                ),
              )),
              const SizedBox(width: 8),
              Text(
                _daySpend > widget.budgetHarian
                  ? 'Over Rp ${formatAmount(_daySpend - widget.budgetHarian)}'
                  : 'Sisa Rp ${formatAmount(widget.budgetHarian - _daySpend)}',
                style: TextStyle(
                  color: _daySpend > widget.budgetHarian ? AppColors.chartOver : AppColors.textMuted,
                  fontSize: 10.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
        const SizedBox(height: 12),

        // Daftar transaksi
        Flexible(child: _loading
          ?  Center(child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(color: AppColors.primary)))
          : _error
            ?  Center(child: Padding(
                padding: EdgeInsets.all(30),
                child: Text('Gagal memuat transaksi',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12))))
            : _dayTx.isEmpty
              ?  Center(child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_outlined, color: AppColors.textHint, size: 32),
                    SizedBox(height: 10),
                    Text('Tidak ada transaksi pada hari ini',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                  ])))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: _dayTx.map((tx) {
                    final kat = getKategoriInfo(tx.kategori);
                    final isIncome = tx.jenis == 'pemasukan';
                    final waktu = (tx.tanggal ?? '').toString().length > 10
                      ? formatTime(tx.tanggal.toString()) : '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder)),
                      child: Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Color(kat.color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(11)),
                          child: Center(child: Text(kat.icon,
                            style: const TextStyle(fontSize: 17)))),
                        const SizedBox(width: 11),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            (tx.deskripsi ?? '').toString().isEmpty
                              ? tx.kategori.toString() : tx.deskripsi.toString(),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style:  TextStyle(color: AppColors.textPrimary,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '${tx.kategori}'
                            '${waktu.isNotEmpty ? ' · $waktu' : ''}'
                            '${(tx.metodePembayaran ?? '').toString().isNotEmpty ? ' · ${tx.metodePembayaran}' : ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style:  TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
                        ])),
                        const SizedBox(width: 8),
                        Text('${isIncome ? '+' : '-'}Rp ${formatAmount((tx.nominal as num).toDouble())}',
                          style: TextStyle(
                            color: isIncome ? AppColors.income : AppColors.expense,
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ]),
                    );
                  }).toList(),
                ),
        ),
      ]),
    );
  }
}
