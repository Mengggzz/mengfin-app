import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';
import '../widgets/widgets.dart';
import 'calendar_screen.dart';
import 'laporan_screen.dart';
import 'ai_screen.dart';
import 'scan_screen.dart';
import 'anggaran_screen.dart';

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
  bool _hasUpdate = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    try {
      final res = await ApiService.checkUpdate();
      setState(() => _hasUpdate = res['has_update'] ?? false);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final results = await Future.wait([
        ApiService.getDashboard(),
        ApiService.getTransaksi(limit: 10),
      ]);
      setState(() {
        _data = results[0] as DashboardData;
        _recentTx = results[1] as List;
        _loading = false;
        _isOfflineData = false;
      });
    } catch (e) {
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
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Home', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
              child: _headerIcon(Icons.camera_alt_outlined),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
              child: _headerIcon(Icons.calendar_today),
            ),
            const SizedBox(width: 8),
            Stack(
              children: [
                _headerIcon(Icons.notifications_outlined),
            if (_hasUpdate)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              ],
            ),
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

        // ── Quick Actions ────────────────────────────────────────
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiScreen())),
              child: const QuickActionButton(
                icon: Icons.auto_awesome,
                label: 'Kazz AI',
                iconColor: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
              child: const QuickActionButton(
                icon: Icons.camera_alt,
                label: 'Scan Struk',
                iconColor: AppColors.expense,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnggaranScreen())),
              child: const QuickActionButton(
                icon: Icons.pie_chart,
                label: 'Budget',
                iconColor: AppColors.expense,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.bgCard,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (_) => _HomeSettingsSheet(),
              );
            },
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

        // ── Budget Harian ────────────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnggaranScreen())),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Budget Harian', style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(
                    _data != null ? 'Rp ${formatAmount((100000 - _data!.rataHarian.toInt()).toDouble())} tersisa' : 'Rp 100.000 batas',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ),
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
              ...entry.value.map((tx) => TransaksiTile(tx: tx)),
            ],
          )),
      ]),
    ));
  }

  bool _isToday(String dateStr) {
    final today = DateTime.now();
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    return date.year == today.year && date.month == today.month && date.day == today.day;
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

// ── Home settings sheet (copy from more_screen)
class _HomeSettingsSheet extends StatefulWidget {
  @override State<_HomeSettingsSheet> createState() => _HomeSettingsSheetState();
}

class _HomeSettingsSheetState extends State<_HomeSettingsSheet> {
  int _dataMode = 0; // 0 = 7 hari terakhir, 1 = Siklus aktif
  bool _showChart = true;
  bool _showBudget = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft, child: Text('Pengaturan beranda',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        const Align(alignment: Alignment.centerLeft, child: Text(
          'Sesuaikan tampilan dan perilaku layar beranda kamu.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
        const SizedBox(height: 16),

        _dataModeOption(0, Icons.bolt, '7 hari terakhir',
          'Ringan. Muat seketika — cocok untuk cek harian.'),
        const SizedBox(height: 8),
        _dataModeOption(1, Icons.calendar_month, 'Siklus aktif (Sep 2026)',
          'Tampilan satu siklus penuh. Mengambil lebih banyak data.'),
        const SizedBox(height: 20),

        const Align(alignment: Alignment.centerLeft, child: Text('Tampilan',
          style: TextStyle(color: AppColors.expense, fontSize: 13, fontWeight: FontWeight.w600))),
        const SizedBox(height: 12),
        _toggleRow('Tampilkan grafik segmen', _showChart, (v) => setState(() => _showChart = v)),
        _toggleRow('Tampilkan budget harian', _showBudget, (v) => setState(() => _showBudget = v)),
        const SizedBox(height: 20),

        const Align(alignment: Alignment.centerLeft, child: Text('Aksi cepat',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        _menuRow(Icons.sort, 'Urutkan aksi cepat', 'Sesuaikan urutan tombol aksi cepat Anda'),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text('Tutup', style: TextStyle(
            color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ]),
    );
  }

  Widget _dataModeOption(int idx, IconData icon, String title, String desc) => GestureDetector(
    onTap: () => setState(() => _dataMode = idx),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _dataMode == idx ? AppColors.primary.withOpacity(0.1) : AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _dataMode == idx ? AppColors.primary : AppColors.glassBorder),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: _dataMode == idx ? AppColors.primary : AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
            color: _dataMode == idx ? AppColors.primary : AppColors.textPrimary,
            fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        if (_dataMode == idx)
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
      ]),
    ),
  );

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecond, fontSize: 13)),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        inactiveTrackColor: AppColors.bgElevated,
      ),
    ]),
  );

  Widget _menuRow(IconData icon, String title, String subtitle) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.textMuted),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ])),
      const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
    ]),
  );
}
