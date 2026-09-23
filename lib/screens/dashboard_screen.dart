import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../services/update_service.dart';
import '../widgets/widgets.dart';
import '../widgets/update_dialog.dart';
import 'ai_screen.dart';
import 'anggaran_screen.dart';
import 'calendar_screen.dart';
import 'laporan_screen.dart';
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

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _hapusTransaksi(dynamic tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Hapus Transaksi?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Tindakan ini tidak dapat dibatalkan.', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
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

      setState(() {
        _data = results[0] as DashboardData;
        _recentTx = allTx.take(10).toList();
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
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
      const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 48),
      const SizedBox(height: 16),
      const Text('Gagal memuat data', style: TextStyle(
        color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Periksa koneksi internet', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
      child: const Row(children: [
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
          const Text('Home', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
          Row(children: [
            _headerIcon(Icons.calendar_today_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()))),
            const SizedBox(width: 8),
            _headerIcon(Icons.bar_chart_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaporanScreen()))),
            const SizedBox(width: 8),
            _headerIcon(Icons.notifications_outlined, onTap: () => _handleDiscordUpdate()),
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
                const Text('Dompet Saya', style: TextStyle(
                  color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                const Icon(Icons.lock_outline, size: 13, color: AppColors.textMuted),
              ]),
              const SizedBox(height: 6),
              Text(
                '${d.saldoTotal < 0 ? '-' : ''}Rp ${formatAmount(d.saldoTotal.abs())}',
                style: TextStyle(
                  color: d.saldoTotal < 0 ? AppColors.expense : AppColors.income,
                  fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text('1 dompet · ketuk untuk kelola',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Dompet Utama', style: TextStyle(
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
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const VoiceToTextDialog(),
                );
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiScreen())),
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
                child: const Icon(Icons.tune, size: 18, color: AppColors.textMuted),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Saldo vs Pengeluaran Chart ──────────────────────────
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Saldo vs Pengeluaran', style: TextStyle(
              color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w600)),
            Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(
                color: AppColors.income, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Container(width: 6, height: 6, decoration: BoxDecoration(
                color: AppColors.expense, shape: BoxShape.circle)),
            ]),
          ]),
          const Text('7 hari', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 12),

          Row(children: [
            // Donut chart
            SizedBox(
              width: 90, height: 90,
              child: Stack(alignment: Alignment.center, children: [
                PieChart(PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: saldoPersen > 0 ? saldoPersen : 0.1,
                      color: AppColors.income,
                      radius: 12,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: pengeluaranPersen > 0 ? pengeluaranPersen : 0.1,
                      color: AppColors.expense,
                      radius: 12,
                      showTitle: false,
                    ),
                  ],
                  centerSpaceRadius: 28,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                )),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${saldoPersen.toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                  const Text('Saldo', style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
                ]),
              ]),
            ),
            const SizedBox(width: 20),
            Expanded(child: Column(children: [
              _chartLegend('Saldo', '${saldoPersen.toStringAsFixed(0)}%', '', AppColors.income),
              const SizedBox(height: 6),
              _chartLegend('Pengeluaran', '${pengeluaranPersen.toStringAsFixed(0)}%',
                'Rp ${formatAmount(d.pengeluaranBulanIni)}', AppColors.expense),
            ])),
          ]),

          // Warning if expense > saldo
          if (d.pengeluaranBulanIni > d.saldoTotal.abs() && d.saldoTotal < 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Text('Saldo minus ', style: TextStyle(
                  color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w700)),
                Text('Pengeluaran melebihi total saldo', style: TextStyle(
                  color: AppColors.warning, fontSize: 11)),
              ]),
            ),
          ],
        ])),
        const SizedBox(height: 12),

        // ── Budget Harian (2. diperbaiki fungsinya, 1. analytics digabung) ─
        _buildBudgetHarianCard(),
        const SizedBox(height: 20),

        // ── Transactions Header ──────────────────────────────────
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Transaksi', style: TextStyle(
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
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
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
          const Center(child: Padding(padding: EdgeInsets.all(20),
            child: Text('Belum ada transaksi', style: TextStyle(color: AppColors.textMuted))))
        else
          ...groupedTx.entries.map((entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _isToday(entry.key) ? 'Hari ini, ${formatTanggalShort(entry.key)}' : formatTanggalShort(entry.key),
                  style: const TextStyle(
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
      // Header — clean, tanpa duplikasi "Over Budget"
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          const Text('Budget Harian', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _editBudgetHarian(),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.edit_outlined, size: 12, color: AppColors.textMuted),
            ),
          ),
        ]),
        if (_budgetHarian > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgElevated, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Text('Rp ${formatAmount(_budgetHarian)}/hari',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
          )
        else
          const Text('Belum diatur', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ]),

      if (_budgetHarian > 0) ...[
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
                  progress >= 1.0 ? AppColors.expense :
                  progress >= 0.8 ? AppColors.warning : AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: progress >= 1.0 ? AppColors.expense : progress >= 0.8 ? AppColors.warning : AppColors.textMuted,
              fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
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
              // garis budget dashed
              if (_budgetHarian > 0)
                Positioned(
                  left: 0, right: 0, bottom: 18 + budgetH,
                  child: Row(children: [
                    Expanded(child: CustomPaint(
                      size: const Size(double.infinity, 1),
                      painter: _DashedLinePainter(color: AppColors.warning.withOpacity(0.55)),
                    )),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.warning.withOpacity(0.25)),
                      ),
                      child: Text('budget ${_compactLabel(_budgetHarian)}',
                        style: const TextStyle(color: AppColors.warning, fontSize: 7, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              // bars
              Row(
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
                    onTap: val > 0 ? () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${dayNames[(day.weekday - 1) % 7]} ${day.day}: Rp ${formatAmount(val)}'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ));
                    } : null,
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      // dot over indicator
                      SizedBox(
                        height: 12,
                        child: isOver
                          ? Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.expense, shape: BoxShape.circle))
                          : const SizedBox(),
                      ),
                      // value label — compact, tidak numpuk
                      SizedBox(
                        height: 12,
                        child: showLabel
                          ? Text(_compactLabel(val),
                              style: TextStyle(
                                color: isOver ? AppColors.expense : AppColors.textMuted,
                                fontSize: 7.5, fontWeight: isToday ? FontWeight.w700 : FontWeight.w500))
                          : const SizedBox(),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 22,
                        height: barH < 3 && val > 0 ? 3 : barH,
                        decoration: BoxDecoration(
                          color: val == 0
                            ? AppColors.bgElevated
                            : isOver ? AppColors.expense : AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                          border: isToday
                            ? Border.all(color: AppColors.textPrimary.withOpacity(0.35), width: 1)
                            : null,
                          boxShadow: isToday && val > 0
                            ? [BoxShadow(color: AppColors.primary.withOpacity(0.18), blurRadius: 6, offset: const Offset(0, 2))]
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
            ]);
          }),
        ),
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
            child: const Row(children: [
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
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
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

  Widget _budgetStat(String label, String value, {Color? valueColor}) => Column(children: [
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
    const SizedBox(height: 2),
    Text(value, style: TextStyle(
      color: valueColor ?? AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);

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
        title: const Text('Atur Budget Harian', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Masukkan batas pengeluaran per hari',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 16),
              hintText: '20000',
              hintStyle: const TextStyle(color: AppColors.textMuted),
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
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0;
              Navigator.pop(ctx, val);
            },
            child: const Text('Simpan', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
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
  // 3. Notifikasi → Cek update dari Discord/GitHub + langsung update
  // ══════════════════════════════════════════════════════════════
  Future<void> _handleDiscordUpdate() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Row(children: [
          SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
          SizedBox(width: 16),
          Text('Memeriksa update...', style: TextStyle(color: AppColors.textSecond, fontSize: 14)),
        ]),
      ),
    );

    try {
      // Reset check supaya bisa cek ulang
      UpdateService.instance.resetCheck();
      final result = await UpdateService.instance.checkForUpdate();

      if (!mounted) return;
      Navigator.pop(context); // Tutup loading

      if (result.hasUpdate && result.release != null) {
        // Ada update → tampilkan UpdateDialog yang sudah ada
        await UpdateDialog.show(context, result);
      } else {
        // Tidak ada update
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.income.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.income, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Sudah Terbaru!', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('MengFin v${result.currentVersion}', style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              const Text('Kamu sudah menggunakan versi terbaru',
                style: TextStyle(color: AppColors.textSecond, fontSize: 13),
                textAlign: TextAlign.center),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Tutup loading
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
          const Text('Pengaturan Beranda', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Kelola tampilan dan widget di halaman utama',
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
      title: Text(title, style: const TextStyle(
        color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(
        color: AppColors.textMuted, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
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

  Widget _chartLegend(String label, String persen, String amount, Color color) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(
      color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(color: AppColors.textSecond, fontSize: 12)),
    const Spacer(),
    Text(persen, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
    if (amount.isNotEmpty) ...[
      const SizedBox(width: 6),
      Text(amount, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ],
  ]);
}
