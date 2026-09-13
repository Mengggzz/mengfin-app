import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';
import '../widgets/widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  List<dynamic> _recentTx = [];
  bool _loading = true;
  bool _isOfflineData = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getDashboard(),
        ApiService.getTransaksi(limit: 5),
      ]);
      setState(() {
        _data = results[0] as DashboardData;
        _recentTx = results[1] as List;
        _loading = false;
        _isOfflineData = false;
      });
    } catch (e) {
      // Fallback ke data lokal
      try {
        final bulan = currentBulan();
        final localStats = await LocalDb.getDashboardLocal(bulan);
        final recentTx = await LocalDb.getTransaksi(limit: 5);
        final saldo = localStats['saldo'] ?? 0;
        final pemasukan = localStats['pemasukan'] ?? 0;
        final pengeluaran = localStats['pengeluaran'] ?? 0;

        setState(() {
          _data = DashboardData(
            saldoTotal: saldo,
            pemasukanBulanIni: pemasukan,
            pengeluaranBulanIni: pengeluaran,
            bulanIni: bulan,
            health: HealthScore(score: 0, status: 'Offline', warna: '#606080', pesan: 'Data lokal tersedia'),
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
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading || _data == null
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.bgCard,
            onRefresh: _load,
            child: CustomScrollView(slivers: [
              if (_isOfflineData)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 52, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                        SizedBox(width: 8),
                        Text('Menampilkan data lokal · Refresh saat online untuk update',
                          style: TextStyle(color: AppColors.warning, fontSize: 11)),
                      ]),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: _buildContent()),
            ]),
          ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    final healthColor = _hexColor(d.health.warna);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Selamat datang 👋', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const Text('MengFin', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          ]),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.notifications_outlined, color: AppColors.textSecond, size: 20),
          ),
        ]),
        const SizedBox(height: 20),

        // Balance Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.gradientPrimary,
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Total Saldo', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            CurrencyText(d.saldoTotal, fontSize: 32, fontWeight: FontWeight.w800,
              color: Colors.white),
            Text(formatBulan(d.bulanIni), style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 20),
            Row(children: [
              _incExpItem('Pemasukan', d.pemasukanBulanIni, true),
              Container(width: 1, height: 40, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 16)),
              _incExpItem('Pengeluaran', d.pengeluaranBulanIni, false),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // Health Score + Prediction row
        Row(children: [
          Expanded(child: GlassCard(child: Column(children: [
            const Align(alignment: Alignment.centerLeft,
              child: Text('Health Score', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
            HealthScoreGauge(score: d.health.score, status: d.health.status, color: healthColor),
            const SizedBox(height: 8),
            Text(d.health.pesan, style: TextStyle(color: healthColor, fontSize: 11),
              textAlign: TextAlign.center),
          ]))),
          const SizedBox(width: 12),
          Expanded(child: GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Prediksi Saldo', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _predRow('Rata/Hari', formatRupiah(d.rataHarian), AppColors.warning),
            _predRow('Sisa Hari', '${d.sisaHari} hari', AppColors.textPrimary),
            _predRow('Akhir Bulan', formatRupiah(d.prediksiSaldoAkhir.abs()),
              d.prediksiSaldoAkhir >= 0 ? AppColors.success : AppColors.danger),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: (d.prediksiStatus == 'aman' ? AppColors.success : AppColors.danger).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(
                d.prediksiStatus == 'aman' ? '✅ Aman' : '⚠️ Perlu Perhatian',
                style: TextStyle(
                  color: d.prediksiStatus == 'aman' ? AppColors.success : AppColors.danger,
                  fontSize: 11, fontWeight: FontWeight.w600,
                ),
              )),
            ),
          ]))),
        ]),
        const SizedBox(height: 12),

        // Minggu Ini
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Minggu Ini', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(d.mingguPeriode, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _weekStat('Pengeluaran', formatRupiah(d.mingguIniPengeluaran), AppColors.danger),
            _weekStat('Rata/Hari', formatRupiah(d.rataHarian), AppColors.warning),
            _weekStat('Terbesar', d.kategoriTerbesar, AppColors.primary),
          ]),
          if (d.kenaikanPersen != 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (d.kenaikanPersen > 0 ? AppColors.danger : AppColors.success).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(d.kenaikanPersen > 0 ? Icons.trending_up : Icons.trending_down,
                  size: 14, color: d.kenaikanPersen > 0 ? AppColors.danger : AppColors.success),
                const SizedBox(width: 6),
                Text('${d.kenaikanPersen.abs()}% dari minggu lalu',
                  style: TextStyle(fontSize: 12,
                    color: d.kenaikanPersen > 0 ? AppColors.danger : AppColors.success)),
              ]),
            ),
          ],
        ])),
        const SizedBox(height: 20),

        // Recent Transactions
        const Text('Transaksi Terbaru', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (_recentTx.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20),
            child: Text('Belum ada transaksi', style: TextStyle(color: AppColors.textMuted)))),
        ..._recentTx.map((tx) => TransaksiTile(tx: tx)),
      ]),
    );
  }

  Widget _incExpItem(String label, double amount, bool isIncome) => Expanded(
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: (isIncome ? AppColors.success : AppColors.danger).withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          size: 16, color: isIncome ? AppColors.success : AppColors.danger),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        CurrencyText(amount, short: true, color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
      ]),
    ]),
  );

  Widget _predRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _weekStat(String label, String value, Color color) => Column(children: [
    Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
  ]);

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) { return AppColors.success; }
  }
}
