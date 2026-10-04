import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});
  @override State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  int _tabIndex = 0; // 0 = Ringkasan, 1 = Bandingkan
  String _periode = currentBulan();
  DashboardData? _data;
  List<Transaksi> _transactions = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getDashboard(),
        ApiService.getTransaksi(limit: 200),
      ]);
      setState(() {
        _data = results[0] as DashboardData;
        _transactions = results[1] as List<Transaksi>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  double get _totalPemasukan => _data?.pemasukanBulanIni ?? 0;
  double get _totalPengeluaran => _data?.pengeluaranBulanIni ?? 0;
  double get _netCashFlow => _totalPemasukan - _totalPengeluaran;

  Future<void> _generateAINarrative() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Analisis AI', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: ApiService.chat("Berikan analisis narasi singkat tentang laporan keuangan saya bulan ini berdasarkan data transaksi yang ada."),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }
                  final data = snapshot.data;
                  final pesan = data?['pesan'] ?? 'Gagal memuat analisis.';
                  return SingleChildScrollView(
                    child: Text(
                      pesan,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.6),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Laporan', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.textSecond, size: 18),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        // ── Period Selector ────────────────────────────────
        GestureDetector(
          onTap: () async {
            final DateTimeRange? picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: AppColors.bgCard,
                      onSurface: AppColors.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              // Handle filter by range
              setState(() {
                _loading = true;
              });
              // logic filter data via API or local
              _load();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Custom range · ${formatBulan(_periode)}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('1 ${formatBulanShort(_periode)} – ${DateTime.now().day} ${formatBulanShort(_periode)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ]),
              ]),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // ── Tabs: Ringkasan / Bandingkan ──────────────────
        SegmentedTab(
          tabs: const ['Ringkasan', 'Bandingkan'],
          selectedIndex: _tabIndex,
          onChanged: (i) => setState(() => _tabIndex = i),
        ),
        const SizedBox(height: 16),

        if (_tabIndex == 0) _buildRingkasan()
        else _buildBandingkan(),
      ]),
    );
  }

  Widget _buildRingkasan() {
    final pemasukanPersen = (_totalPemasukan + _totalPengeluaran) > 0
        ? (_totalPemasukan / (_totalPemasukan + _totalPengeluaran) * 100) : 0.0;
    final pengeluaranPersen = 100 - pemasukanPersen;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Arus Kas Bersih ──────────────────────────────────
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Arus kas bersih', style: TextStyle(
          color: AppColors.textSecond, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          '${_netCashFlow < 0 ? '-' : ''}Rp ${formatAmount(_netCashFlow.abs())}',
          style: TextStyle(
            color: _netCashFlow >= 0 ? AppColors.income : AppColors.expense,
            fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),

        // Donut chart
        Row(children: [
          SizedBox(
            width: 100, height: 100,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sections: [
                  PieChartSectionData(
                    value: _totalPemasukan > 0 ? _totalPemasukan : 0.1,
                    color: AppColors.income,
                    radius: 14,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: _totalPengeluaran > 0 ? _totalPengeluaran : 0.1,
                    color: AppColors.expense,
                    radius: 14,
                    showTitle: false,
                  ),
                ],
                centerSpaceRadius: 30,
                sectionsSpace: 2,
                startDegreeOffset: -90,
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_netCashFlow >= 0 ? 'Masuk' : 'Keluar',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                Text('Rp ${formatAmount(_netCashFlow.abs() > 999 ? _netCashFlow.abs() / 1000 : _netCashFlow.abs())}${_netCashFlow.abs() > 999 ? 'rb' : ''}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          const SizedBox(width: 20),
          Expanded(child: Column(children: [
            _legendRow('Pemasukan', _totalPemasukan, pemasukanPersen, AppColors.income),
            const SizedBox(height: 8),
            _legendRow('Pengeluaran', _totalPengeluaran, pengeluaranPersen, AppColors.expense),
          ])),
        ]),
      ])),
      const SizedBox(height: 12),

      // ── Pergerakan Uang ──────────────────────────────────
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Pergerakan uang', style: TextStyle(
            color: AppColors.textSecond, fontSize: 14, fontWeight: FontWeight.w600)),
          const Text('Rp 0', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        const Text('Tidak ada transfer internal pada periode ini',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ])),
      const SizedBox(height: 12),

      // ── Transfer as cash flow toggle ──────────────────────
      GlassCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text('Anggap transfer sebagai arus kas', style: TextStyle(
              color: AppColors.textSecond, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
          ]),
          Switch(
            value: false,
            onChanged: (_) {},
            activeColor: AppColors.primary,
            inactiveTrackColor: AppColors.bgElevated,
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Tujuan Pengeluaran ─────────────────────────────────
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tujuan pengeluaran', style: TextStyle(
          color: AppColors.textSecond, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(
            width: 90, height: 90,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sections: [
                  PieChartSectionData(value: 62.5, color: AppColors.typeNeed, radius: 12, showTitle: false),
                  PieChartSectionData(value: 37.5, color: AppColors.typeWant, radius: 12, showTitle: false),
                ],
                centerSpaceRadius: 28,
                sectionsSpace: 2,
                startDegreeOffset: -90,
              )),
              const Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Kebutuhan', style: TextStyle(color: AppColors.textMuted, fontSize: 8)),
                Text('62.5%', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          const SizedBox(width: 20),
          Expanded(child: Column(children: [
            _purposeRow('Need', _totalPengeluaran * 0.625, 62.5, AppColors.typeNeed),
            const SizedBox(height: 8),
            _purposeRow('Want', _totalPengeluaran * 0.375, 37.5, AppColors.typeWant),
          ])),
        ]),
      ])),
      const SizedBox(height: 16),

      // ── AI Narrative Button ─────────────────────────────────
      GestureDetector(
        onTap: _generateAINarrative,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.gradientPrimary,
              begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('Buat Narasi AI dari Laporan ini', style: TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _legendRow(String label, double amount, double persen, Color color) =>
    Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: AppColors.textSecond, fontSize: 12)),
      const Spacer(),
      Text('Rp ${formatAmount(amount > 999 ? amount / 1000 : amount)}${amount > 999 ? 'rb' : ''}',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      Text('${persen.toStringAsFixed(1)}%',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ]);

  Widget _purposeRow(String label, double amount, double persen, Color color) =>
    Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: AppColors.textSecond, fontSize: 12)),
      const Spacer(),
      Text('Rp ${formatAmount(amount > 999 ? amount / 1000 : amount)}${amount > 999 ? ' rb' : ''}',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      Text('${persen.toStringAsFixed(1)}%',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ]);

  Widget _buildBandingkan() {
    return Column(children: [
      const SizedBox(height: 40),
      const Icon(Icons.compare_arrows, size: 48, color: AppColors.textMuted),
      const SizedBox(height: 16),
      const Text('Fitur Bandingkan', style: TextStyle(
        color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Bandingkan data keuanganmu\nantar periode bulan yang berbeda',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4)),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur bandingkan segera hadir')));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: const Text('Segera Hadir'),
      ),
      const SizedBox(height: 40),
    ]);
  }
}
