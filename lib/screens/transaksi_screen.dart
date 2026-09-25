import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_events.dart';
import '../widgets/widgets.dart';
import 'calendar_screen.dart';
import 'laporan_screen.dart';

import '../services/export_service.dart';
import '../widgets/transaction_filter_dialog.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});
  @override State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  List<Transaksi> _list = [];
  List<Transaksi> _filteredList = [];
  bool _loading = true;
  TransactionFilter _currentFilter = TransactionFilter();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applySearch);
    // Ikut menyegarkan diri saat transaksi berubah dari layar lain
    // (input manual, scan struk, voice, hapus) — tanpa pull-to-refresh.
    AppEvents.instance.transaksi.addListener(_load);
  }

  @override
  void dispose() {
    AppEvents.instance.transaksi.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Load all for local filtering, or we could pass params to API
      // For now, let's load a larger set and filter locally for speed
      final data = await ApiService.getTransaksi(limit: 500);
      _list = data;
      _applyAllFilters();
      setState(() => _loading = false);
    } catch (_) { setState(() => _loading = false); }
  }

  void _applyAllFilters() {
    List<Transaksi> filtered = _list;

    // Type Filter (Jenis)
    if (_currentFilter.jenis != null) {
      filtered = filtered.where((tx) => tx.jenis == _currentFilter.jenis).toList();
    }

    // Category Filter
    if (_currentFilter.kategori != null) {
      filtered = filtered.where((tx) => tx.kategori == _currentFilter.kategori).toList();
    }

    // Date Filter
    if (_currentFilter.startDate != null && _currentFilter.endDate != null) {
      filtered = filtered.where((tx) {
        DateTime txDate = DateTime.parse(tx.tanggal);
        return txDate.isAfter(_currentFilter.startDate!.subtract(const Duration(days: 1))) &&
               txDate.isBefore(_currentFilter.endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    _filteredList = filtered;
    _applySearch();
  }

  void _applySearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredList = _filteredList; // This logic needs careful state management
        // Re-run apply filters to get base filtered list
        List<Transaksi> base = _list;
        if (_currentFilter.jenis != null) base = base.where((tx) => tx.jenis == _currentFilter.jenis).toList();
        if (_currentFilter.kategori != null) base = base.where((tx) => tx.kategori == _currentFilter.kategori).toList();
        if (_currentFilter.startDate != null && _currentFilter.endDate != null) {
          base = base.where((tx) {
            DateTime txDate = DateTime.parse(tx.tanggal);
            return txDate.isAfter(_currentFilter.startDate!.subtract(const Duration(days: 1))) &&
                   txDate.isBefore(_currentFilter.endDate!.add(const Duration(days: 1)));
          }).toList();
        }
        _filteredList = base;
      } else {
        _filteredList = _filteredList.where((tx) => 
          tx.deskripsi.toLowerCase().contains(query) || 
          tx.kategori.toLowerCase().contains(query)
        ).toList();
      }
    });
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionFilterDialog(currentFilter: _currentFilter),
    );

    if (result != null) {
      setState(() {
        _currentFilter = result;
        _applyAllFilters();
      });
    }
  }

  Future<void> _export(String type) async {
    if (type == 'csv') {
      await ExportService.exportToCSV(_filteredList, context);
    } else {
      await ExportService.exportToPDF(_filteredList, context);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title:  Text('Hapus Transaksi', style: TextStyle(color: AppColors.textPrimary)),
      content:  Text('Yakin hapus?', style: TextStyle(color: AppColors.textSecond)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child:  Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child:  Text('Hapus', style: TextStyle(color: AppColors.danger))),
      ],
    ));
    if (ok == true) { await ApiService.deleteTransaksi(id); _load(); }
  }

  // Group transaksi by date
  Map<String, List<Transaksi>> get _grouped {
    final map = <String, List<Transaksi>>{};
    for (final tx in _list) {
      final date = tx.tanggal.length > 10 ? tx.tanggal.substring(0, 10) : tx.tanggal;
      map.putIfAbsent(date, () => []).add(tx);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Column(children: [
        // ── Header ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text('Transaksi', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CalendarScreen())),
                  child: _headerIcon(Icons.calendar_month_outlined),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LaporanScreen())),
                  child: _headerIcon(Icons.bar_chart),
                ),
                const SizedBox(width: 8),
                _headerIcon(Icons.schedule),
              ]),
            ]),
            const SizedBox(height: 6),
             Text(
              'Lihat transaksi dari beberapa dompet sekaligus dalam satu tampilan.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                  ),
                ]),
                const SizedBox(height: 10),
                const Text('Lihat semuanya di satu tempat', style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Pasang filter untuk menarik transaksi dari dompet mana pun — berdasarkan tanggal, kategori, atau kata kunci.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
              ]),
            ),
            const SizedBox(height: 12),
          ]),
        ),

        // ── Filter Bar ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _filterBtn('Buka filter', Icons.tune, () {}),
            const Spacer(),
            // Type filter circles
            _typeCircle('semua', Icons.receipt_long, AppColors.primary),
            const SizedBox(width: 6),
            _typeCircle('pemasukan', Icons.arrow_downward, AppColors.income),
            const SizedBox(width: 6),
            _typeCircle('pengeluaran', Icons.arrow_upward, AppColors.expense),
          ]),
        ),
        const SizedBox(height: 12),

        // ── List ───────────────────────────────────────────────
        if (_loading)
           Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
        else Expanded(
          child: RefreshIndicator(
            color: AppColors.primary, backgroundColor: AppColors.bgCard,
            onRefresh: _load,
            child: _list.isEmpty
              ?  Center(child: Text('Belum ada transaksi',
                  style: TextStyle(color: AppColors.textMuted)))
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _grouped.entries.map((e) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(formatTanggal(e.key),
                            style:  TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                          Text('${e.value.length} transaksi',
                            style:  TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        ]),
                      ),
                      ...e.value.map((tx) => Stack(
                        children: [
                          TransaksiTile(
                            tx: tx,
                            onDelete: () => _delete(tx.id),
                          ),
                          if (!tx.synced)
                            Positioned(
                              top: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                                ),
                                child:  Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.cloud_upload_outlined, size: 10, color: AppColors.warning),
                                  SizedBox(width: 3),
                                  Text('Sync', style: TextStyle(
                                    color: AppColors.warning, fontSize: 9, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                        ],
                      )),
                    ],
                  )).toList(),
                ),
          ),
        ),
      ])),
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

  Widget _filterBtn(String label, IconData icon, VoidCallback onTap, {bool active = false}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: active ? Colors.white : AppColors.primary),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
          color: active ? Colors.white : AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _typeCircle(String type, IconData icon, Color color) {
    final currentType = _currentFilter.jenis ?? 'semua';
    return GestureDetector(
      onTap: () { 
        setState(() {
          _currentFilter = TransactionFilter(
            startDate: _currentFilter.startDate,
            endDate: _currentFilter.endDate,
            jenis: type == 'semua' ? null : type,
            kategori: _currentFilter.kategori,
          );
          _applyAllFilters();
        });
      },
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: currentType == type ? color : color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(icon, size: 14,
          color: currentType == type ? Colors.white : color),
      ),
    );
  }
}
