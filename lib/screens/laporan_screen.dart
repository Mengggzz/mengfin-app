import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/export_service.dart';
import '../widgets/widgets.dart';

/// Kategori yang dianggap Kebutuhan (Need) — sisanya Want, kecuali Saving.
const Set<String> _needKategori = {
  'Makan & Minum', 'Transportasi', 'Kesehatan', 'Pendidikan', 'Tagihan',
  'Pajak & Asuransi', 'Rumah Tangga', 'Kendaraan', 'Pemeliharaan',
  'Kerja', 'Keluarga', 'Perawatan',
};
const Set<String> _savingKategori = {'Investasi'};

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});
  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  int _tabIndex = 0; // 0 = Ringkasan, 1 = Bandingkan
  String _periode = currentBulan();
  List<Transaksi> _allTx = [];
  bool _loading = true;
  bool _transferAsCashflow = false;

  // Narasi AI
  bool _narasiLoading = false;
  String? _narasi;
  String? _narasiError;

  // Bandingkan
  String _periodePembanding = _prevBulan(currentBulan());
  bool _compareLoading = false;
  List<Transaksi>? _compareTx;

  @override
  void initState() { super.initState(); _load(); }

  static String _prevBulan(String yyyymm) {
    final parts = yyyymm.split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]) - 1, 1);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final txs = await ApiService.getTransaksi(limit: 500);
      if (!mounted) return;
      setState(() {
        _allTx = txs;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Data untuk periode terpilih ────────────────────────────────────────────
  List<Transaksi> get _txPeriode => _allTx.where((tx) {
    final d = DateTime.tryParse(tx.tanggal);
    if (d == null) return false;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}' == _periode;
  }).toList();

  double get _totalPemasukan => _txPeriode
      .where((t) => t.jenis == 'pemasukan')
      .fold(0.0, (s, t) => s + t.nominal);

  double get _totalPengeluaran => _txPeriode
      .where((t) => t.jenis == 'pengeluaran')
      .fold(0.0, (s, t) => s + t.nominal);

  double get _totalTransfer => _txPeriode
      .where((t) => t.jenis == 'transfer')
      .fold(0.0, (s, t) => s + t.nominal);

  double get _netCashFlow {
    final base = _totalPemasukan - _totalPengeluaran;
    return _transferAsCashflow ? base - _totalTransfer : base;
  }

  Map<String, double> _kategoriTotals(List<Transaksi> txs) {
    final map = <String, double>{};
    for (final tx in txs.where((t) => t.jenis == 'pengeluaran')) {
      map[tx.kategori] = (map[tx.kategori] ?? 0) + tx.nominal;
    }
    return map;
  }

  /// Need / Want / Saving dari data nyata
  ({double need, double want, double saving}) get _nwsBreakdown {
    double need = 0, want = 0, saving = 0;
    for (final tx in _txPeriode.where((t) => t.jenis == 'pengeluaran')) {
      if (_savingKategori.contains(tx.kategori)) {
        saving += tx.nominal;
      } else if (_needKategori.contains(tx.kategori)) {
        need += tx.nominal;
      } else {
        want += tx.nominal;
      }
    }
    return (need: need, want: want, saving: saving);
  }

  // ── Pilih periode (bulan) ──────────────────────────────────────────────────
  Future<void> _pickPeriode() async {
    final now = DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final months = List.generate(12, (i) => DateTime(now.year, now.month - i, 1));
        return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text(
              'Pilih Periode', style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w700))),
          ),
          Flexible(child: ListView.builder(
            shrinkWrap: true,
            itemCount: months.length,
            itemBuilder: (_, i) {
              final m = months[i];
              final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
              final selected = key == _periode;
              return ListTile(
                dense: true,
                title: Text(formatBulan(key), style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                trailing: selected
                  ? const Icon(Icons.check_circle, color: AppColors.primary, size: 18)
                  : null,
                onTap: () => Navigator.pop(ctx, m),
              );
            },
          )),
          const SizedBox(height: 8),
        ]));
      },
    );
    if (picked != null) {
      setState(() {
        _periode = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
        _narasi = null;
        _narasiError = null;
      });
    }
  }

  // ── Narasi AI ──────────────────────────────────────────────────────────────
  Future<void> _buatNarasi() async {
    setState(() { _narasiLoading = true; _narasiError = null; });
    try {
      final res = await ApiService.getNarasiLaporan(_periode);
      if (!mounted) return;
      setState(() {
        _narasi = (res['narasi'] ?? '').toString();
        _narasiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _narasiLoading = false;
        _narasiError = _prettyError(e);
      });
    }
  }

  String _prettyError(Object e) {
    final s = e.toString();
    final m = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(s);
    if (m != null) return m.group(1)!;
    if (s.contains('SocketException') || s.contains('Connection')) {
      return 'Tidak bisa menghubungi server. Periksa koneksi internet.';
    }
    return 'Gagal membuat narasi. Coba lagi sebentar lagi.';
  }

  // ── Ekspor ─────────────────────────────────────────────────────────────────
  Future<void> _showExportMenu() async {
    final pilihan = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(color: AppColors.textMuted.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2))),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Align(alignment: Alignment.centerLeft, child: Text('Ekspor Laporan',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Align(alignment: Alignment.centerLeft, child: Text(
            'Unduh transaksi periode terpilih sebagai file',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
        ),
        ListTile(
          leading: Container(width: 40, height: 40, decoration: BoxDecoration(
            color: AppColors.income.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.table_chart_outlined, color: AppColors.income, size: 20)),
          title: const Text('Ekspor CSV', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('Buka di Excel / Google Sheets', style: TextStyle(
            color: AppColors.textMuted, fontSize: 11)),
          onTap: () => Navigator.pop(ctx, 'csv'),
        ),
        ListTile(
          leading: Container(width: 40, height: 40, decoration: BoxDecoration(
            color: AppColors.expense.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.expense, size: 20)),
          title: const Text('Ekspor PDF', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('Laporan siap cetak / dibagikan', style: TextStyle(
            color: AppColors.textMuted, fontSize: 11)),
          onTap: () => Navigator.pop(ctx, 'pdf'),
        ),
        const SizedBox(height: 8),
      ])),
    );

    if (pilihan == null || !mounted) return;
    final txs = _txPeriode;
    if (txs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tidak ada transaksi pada periode ini'),
        backgroundColor: AppColors.warning));
      return;
    }
    if (pilihan == 'csv') {
      await ExportService.exportToCSV(txs, context);
    } else {
      await ExportService.exportToPDF(txs, context);
    }
  }

  // ── Bandingkan: muat periode pembanding ───────────────────────────────────
  Future<void> _loadCompare() async {
    setState(() => _compareLoading = true);
    try {
      final txs = await ApiService.getTransaksi(limit: 500);
      if (!mounted) return;
      setState(() {
        _compareTx = txs.where((tx) {
          final d = DateTime.tryParse(tx.tanggal);
          if (d == null) return false;
          return '${d.year}-${d.month.toString().padLeft(2, '0')}' == _periodePembanding;
        }).toList();
        _compareLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _compareLoading = false);
    }
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
          IconButton(
            tooltip: 'Ekspor laporan',
            onPressed: _loading ? null : _showExportMenu,
            icon: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder)),
              child: const Icon(Icons.ios_share_rounded,
                color: AppColors.textSecond, size: 17),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.bgCard,
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            // ── Period Selector (fungsional) ────────────────────
            GestureDetector(
              onTap: _pickPeriode,
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
                      Text(formatBulan(_periode),
                        style: const TextStyle(color: AppColors.textPrimary,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${_txPeriode.length} transaksi tercatat',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ]),
                  ]),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted, size: 20),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            SegmentedTab(
              tabs: const ['Ringkasan', 'Bandingkan'],
              selectedIndex: _tabIndex,
              onChanged: (i) {
                setState(() => _tabIndex = i);
                if (i == 1 && _compareTx == null) _loadCompare();
              },
            ),
            const SizedBox(height: 16),

            if (_tabIndex == 0) _buildRingkasan() else _buildBandingkan(),
          ])),
    );
  }

  Widget _buildRingkasan() {
    final nws = _nwsBreakdown;
    final totalNWS = nws.need + nws.want + nws.saving;
    final pemasukanPersen = (_totalPemasukan + _totalPengeluaran) > 0
        ? (_totalPemasukan / (_totalPemasukan + _totalPengeluaran) * 100) : 0.0;
    final pengeluaranPersen = 100 - pemasukanPersen;
    final topKategori = _kategoriTotals(_txPeriode).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
        Row(children: [
          SizedBox(
            width: 100, height: 100,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sections: [
                  PieChartSectionData(
                    value: _totalPemasukan > 0 ? _totalPemasukan : 0.1,
                    color: AppColors.income, radius: 14, showTitle: false),
                  PieChartSectionData(
                    value: _totalPengeluaran > 0 ? _totalPengeluaran : 0.1,
                    color: AppColors.expense, radius: 14, showTitle: false),
                ],
                centerSpaceRadius: 30,
                sectionsSpace: 2,
                startDegreeOffset: -90,
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_netCashFlow >= 0 ? 'Masuk' : 'Keluar',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
                Text('Rp ${formatAmount(_netCashFlow.abs())}',
                  style: const TextStyle(color: AppColors.textPrimary,
                    fontSize: 10, fontWeight: FontWeight.w700)),
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

      // ── Pergerakan uang (transfer internal) ──────────────
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Pergerakan uang', style: TextStyle(
            color: AppColors.textSecond, fontSize: 14, fontWeight: FontWeight.w600)),
          Text('Rp ${formatAmount(_totalTransfer)}', style: TextStyle(
            color: _totalTransfer > 0 ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Text(
          _totalTransfer > 0
            ? '${_txPeriode.where((t) => t.jenis == 'transfer').length} transfer internal pada periode ini'
            : 'Tidak ada transfer internal pada periode ini',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ])),
      const SizedBox(height: 12),

      // ── Transfer as cash flow toggle (fungsional) ────────
      GlassCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text('Anggap transfer sebagai arus kas', style: TextStyle(
              color: AppColors.textSecond, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
          ]),
          Switch(
            value: _transferAsCashflow,
            onChanged: (v) => setState(() => _transferAsCashflow = v),
            activeColor: AppColors.primary,
            inactiveTrackColor: AppColors.bgElevated,
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Tujuan Pengeluaran (Need/Want/Saving dari data nyata) ──
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tujuan pengeluaran', style: TextStyle(
          color: AppColors.textSecond, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        if (totalNWS <= 0)
          const Padding(padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Belum ada pengeluaran pada periode ini',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
        else
          Row(children: [
            SizedBox(
              width: 90, height: 90,
              child: Stack(alignment: Alignment.center, children: [
                PieChart(PieChartData(
                  sections: [
                    if (nws.need > 0) PieChartSectionData(value: nws.need,
                      color: AppColors.typeNeed, radius: 12, showTitle: false),
                    if (nws.want > 0) PieChartSectionData(value: nws.want,
                      color: AppColors.typeWant, radius: 12, showTitle: false),
                    if (nws.saving > 0) PieChartSectionData(value: nws.saving,
                      color: AppColors.typeSaving, radius: 12, showTitle: false),
                  ],
                  centerSpaceRadius: 28, sectionsSpace: 2, startDegreeOffset: -90,
                )),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Kebutuhan', style: TextStyle(
                    color: AppColors.textMuted, fontSize: 8)),
                  Text('${(nws.need / totalNWS * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppColors.textPrimary,
                      fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
            const SizedBox(width: 20),
            Expanded(child: Column(children: [
              _purposeRow('Need', nws.need, totalNWS, AppColors.typeNeed),
              const SizedBox(height: 8),
              _purposeRow('Want', nws.want, totalNWS, AppColors.typeWant),
              const SizedBox(height: 8),
              _purposeRow('Saving', nws.saving, totalNWS, AppColors.typeSaving),
            ])),
          ]),
      ])),
      const SizedBox(height: 12),

      // ── Kategori terbesar ────────────────────────────────
      if (topKategori.isNotEmpty) ...[
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Kategori pengeluaran terbesar', style: TextStyle(
            color: AppColors.textSecond, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ...topKategori.take(5).map((e) {
            final kat = getKategoriInfo(e.key);
            final persen = _totalPengeluaran > 0 ? e.value / _totalPengeluaran * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(kat.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key, style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12.5,
                    fontWeight: FontWeight.w600))),
                  Text('Rp ${formatAmount(e.value)}', style: const TextStyle(
                    color: AppColors.textSecond, fontSize: 12,
                    fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  SizedBox(width: 40, child: Text('${persen.toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (persen / 100).clamp(0.0, 1.0), minHeight: 4,
                    backgroundColor: AppColors.bgElevated,
                    valueColor: AlwaysStoppedAnimation(Color(kat.color)),
                  ),
                ),
              ]),
            );
          }),
        ])),
        const SizedBox(height: 12),
      ],

      // ── Narasi AI ────────────────────────────────────────
      if (_narasi != null)
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 3, height: 16, decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('Analisis AI', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          _renderNarasi(_narasi!),
        ])),
      if (_narasi != null) const SizedBox(height: 12),

      if (_narasiError != null) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.expense.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.expense.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.error_outline, color: AppColors.expense, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(_narasiError!, style: const TextStyle(
              color: AppColors.expense, fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 12),
      ],

      // ── AI Narrative Button (fungsional) ─────────────────
      GestureDetector(
        onTap: _narasiLoading ? null : _buatNarasi,
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
                borderRadius: BorderRadius.circular(8)),
              child: _narasiLoading
                ? const Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator(
                    strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              _narasiLoading ? 'Membuat analisis...'
                : (_narasi == null ? 'Buat Narasi AI dari Laporan ini' : 'Buat Ulang Narasi AI'),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  /// Render markdown ringan (**bold**, baris baru) tanpa paket tambahan.
  Widget _renderNarasi(String text) {
    final spans = <TextSpan>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final parts = line.split('**');
      for (var j = 0; j < parts.length; j++) {
        if (parts[j].isEmpty) continue;
        spans.add(TextSpan(
          text: parts[j],
          style: j.isOdd
            ? const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)
            : null,
        ));
      }
      if (i < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return RichText(text: TextSpan(
      style: const TextStyle(color: AppColors.textSecond, fontSize: 12.5, height: 1.65),
      children: spans));
  }

  Widget _legendRow(String label, double amount, double persen, Color color) =>
    Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: AppColors.textSecond, fontSize: 12)),
      const Spacer(),
      Text('Rp ${formatAmount(amount)}',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      Text('${persen.toStringAsFixed(1)}%',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ]);

  Widget _purposeRow(String label, double amount, double total, Color color) =>
    Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: AppColors.textSecond, fontSize: 12)),
      const Spacer(),
      Text('Rp ${formatAmount(amount)}',
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      Text(total > 0 ? '${(amount / total * 100).toStringAsFixed(1)}%' : '0%',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ]);

  // ══════════════════════════════════════════════════════════════
  // Tab Bandingkan — perbandingan nyata antar dua periode
  // ══════════════════════════════════════════════════════════════
  Widget _buildBandingkan() {
    final txA = _txPeriode;
    final txB = _compareTx ?? [];

    double masuk(List<Transaksi> t) =>
      t.where((x) => x.jenis == 'pemasukan').fold(0.0, (s, x) => s + x.nominal);
    double keluar(List<Transaksi> t) =>
      t.where((x) => x.jenis == 'pengeluaran').fold(0.0, (s, x) => s + x.nominal);

    final aMasuk = masuk(txA), aKeluar = keluar(txA);
    final bMasuk = masuk(txB), bKeluar = keluar(txB);
    final maxVal = [aMasuk, aKeluar, bMasuk, bKeluar].fold(0.0, (a, b) => a > b ? a : b);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Pilih periode pembanding
      GestureDetector(
        onTap: _compareLoading ? null : () async {
          final picked = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: AppColors.bgCard,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (ctx) {
              final now = DateTime.now();
              final months = List.generate(12, (i) => DateTime(now.year, now.month - i, 1));
              return SafeArea(child: ListView(shrinkWrap: true, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Align(alignment: Alignment.centerLeft, child: Text(
                    'Bandingkan dengan', style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 16, fontWeight: FontWeight.w700))),
                ),
                ...months.map((m) {
                  final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
                  return ListTile(
                    dense: true,
                    title: Text(formatBulan(key), style: TextStyle(
                      color: key == _periodePembanding ? AppColors.primary : AppColors.textPrimary,
                      fontSize: 14)),
                    trailing: key == _periodePembanding
                      ? const Icon(Icons.check_circle, color: AppColors.primary, size: 18) : null,
                    onTap: () => Navigator.pop(ctx, key),
                  );
                }),
              ]));
            },
          );
          if (picked != null && mounted) {
            setState(() { _periodePembanding = picked; _compareTx = null; });
            await _loadCompare();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              const Icon(Icons.compare_arrows_rounded, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text('${formatBulan(_periode)}  vs  ${formatBulan(_periodePembanding)}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w600)),
            ]),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted, size: 20),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      if (_compareLoading)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
      else ...[
        // Bar chart perbandingan
        GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Perbandingan arus kas', style: TextStyle(
            color: AppColors.textSecond, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(BarChartData(
              maxY: maxVal <= 0 ? 1 : maxVal * 1.25,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.bgElevated,
                  getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                    'Rp ${formatAmount(rod.toY)}',
                    const TextStyle(color: AppColors.textPrimary, fontSize: 11,
                      fontWeight: FontWeight.w700)),
                ),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false,
                horizontalInterval: maxVal <= 0 ? 1 : maxVal * 1.25 / 3,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.textMuted.withOpacity(0.08), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 26,
                  getTitlesWidget: (v, meta) {
                    const labels = ['Masuk', 'Keluar'];
                    final idx = v.toInt();
                    if (idx < 0 || idx >= labels.length) return const SizedBox();
                    return Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(labels[idx], style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10)));
                  },
                )),
              ),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [
                  BarChartRodData(toY: aMasuk, width: 16,
                    gradient: const LinearGradient(colors: AppColors.gradientIncome,
                      begin: Alignment.bottomCenter, end: Alignment.topCenter),
                    borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: bMasuk, width: 16,
                    color: AppColors.income.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(4)),
                ]),
                BarChartGroupData(x: 1, barRods: [
                  BarChartRodData(toY: aKeluar, width: 16,
                    gradient: const LinearGradient(colors: AppColors.gradientChartOver,
                      begin: Alignment.bottomCenter, end: Alignment.topCenter),
                    borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: bKeluar, width: 16,
                    color: AppColors.expense.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(4)),
                ]),
              ],
            )),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _compareLegend(formatBulan(_periode), AppColors.primary),
            const SizedBox(width: 16),
            _compareLegend(formatBulan(_periodePembanding), AppColors.textMuted),
          ]),
        ])),
        const SizedBox(height: 12),

        // Kartu delta
        GlassCard(child: Column(children: [
          _deltaRow('Pemasukan', aMasuk, bMasuk, AppColors.income, true),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.textMuted.withOpacity(0.1)),
          const SizedBox(height: 12),
          _deltaRow('Pengeluaran', aKeluar, bKeluar, AppColors.expense, false),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.textMuted.withOpacity(0.1)),
          const SizedBox(height: 12),
          _deltaRow('Arus kas bersih', aMasuk - aKeluar, bMasuk - bKeluar,
            (aMasuk - aKeluar) >= 0 ? AppColors.income : AppColors.expense, true),
        ])),
      ],
      const SizedBox(height: 24),
    ]);
  }

  Widget _compareLegend(String label, Color color) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(
      color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(color: AppColors.textSecond, fontSize: 11)),
  ]);

  Widget _deltaRow(String label, double a, double b, Color color, bool higherIsBetter) {
    final diff = a - b;
    final persen = b > 0 ? (diff / b * 100) : (a > 0 ? 100.0 : 0.0);
    final naik = diff > 0;
    final bagus = higherIsBetter ? naik : !naik;
    final deltaColor = diff == 0
      ? AppColors.textMuted
      : (bagus ? AppColors.income : AppColors.expense);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(
          color: AppColors.textSecond, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (diff != 0) ...[
          Icon(naik ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14, color: deltaColor),
          const SizedBox(width: 4),
          Text('${persen.abs().toStringAsFixed(1)}%', style: TextStyle(
            color: deltaColor, fontSize: 12, fontWeight: FontWeight.w700)),
        ] else
          const Text('sama', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(formatBulan(_periode), style: const TextStyle(
            color: AppColors.textMuted, fontSize: 10)),
          Text('Rp ${formatAmount(a)}', style: TextStyle(
            color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ])),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(formatBulan(_periodePembanding), style: const TextStyle(
            color: AppColors.textMuted, fontSize: 10)),
          Text('Rp ${formatAmount(b)}', style: const TextStyle(
            color: AppColors.textSecond, fontSize: 13, fontWeight: FontWeight.w600)),
        ])),
      ]),
    ]);
  }
}
