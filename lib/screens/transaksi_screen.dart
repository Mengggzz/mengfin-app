import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_events.dart';
import '../services/local_db.dart';
import '../utils/responsive.dart';
import '../widgets/transaction_filter_dialog.dart';
import '../widgets/widgets.dart';
import 'calendar_screen.dart';
import 'laporan_screen.dart';
import 'transaction_input_screen.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  List<Transaksi> _list = [];
  List<Transaksi> _filteredList = [];
  List<Transaksi> _baseFiltered = [];
  bool _loading = true;
  TransactionFilter _currentFilter = TransactionFilter();
  final TextEditingController _searchController = TextEditingController();

  // Mode Seleksi Multi-Pilih / Hapus
  bool _isSelectionMode = false;
  final Set<dynamic> _selectedIds = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applySearch);
    AppEvents.instance.transaksi.addListener(_load);
  }

  @override
  void dispose() {
    AppEvents.instance.transaksi.removeListener(_load);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_list.isEmpty && !kIsWeb) {
      try {
        final local = await LocalDb.getTransaksi(limit: 500);
        if (mounted && local.isNotEmpty && _list.isEmpty) {
          _list = local;
          _applyAllFilters();
          _loading = false;
          setState(() {});
        }
      } catch (_) {}
    }
    if (_list.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final data = await ApiService.getTransaksi(limit: 500);
      if (!mounted) return;
      _list = data;
      _applyAllFilters();
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyAllFilters() {
    List<Transaksi> result = List.from(_list);

    if (_currentFilter.startDate != null) {
      result = result.where((t) {
        final d = DateTime.tryParse(t.tanggal);
        return d != null && !d.isBefore(_currentFilter.startDate!);
      }).toList();
    }
    if (_currentFilter.endDate != null) {
      result = result.where((t) {
        final d = DateTime.tryParse(t.tanggal);
        return d != null && !d.isAfter(_currentFilter.endDate!);
      }).toList();
    }
    if (_currentFilter.jenis != null) {
      result = result.where((t) => t.jenis == _currentFilter.jenis).toList();
    }
    if (_currentFilter.kategori != null) {
      result = result.where((t) => t.kategori == _currentFilter.kategori).toList();
    }

    _baseFiltered = result;
    _applySearch();
  }

  void _applySearch() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filteredList = List.from(_baseFiltered);
      } else {
        _filteredList = _baseFiltered.where((t) {
          final desc = t.deskripsi.toLowerCase();
          final kat = t.kategori.toLowerCase();
          final nom = t.nominal.toString();
          return desc.contains(q) || kat.contains(q) || nom.contains(q);
        }).toList();
      }
      // Bersihkan ID terpilih yang sudah tidak ada di filtered list
      final validIds = _filteredList.map((t) => t.id).toSet();
      _selectedIds.removeWhere((id) => !validIds.contains(id));
    });
  }

  void _openFilter() async {
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TransactionFilterDialog(currentFilter: _currentFilter),
    );
    if (result != null) {
      setState(() {
        _currentFilter = result;
        _applyAllFilters();
      });
    }
  }

  void _editTransaksi(dynamic tx) {
    if (_isSelectionMode) {
      _toggleSelect(tx.id);
      return;
    }
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => TransactionInputScreen(edit: tx as Transaksi)))
        .then((changed) {
      if (!mounted) return;
      if (changed == true) _load();
    });
  }

  // ── Mode Seleksi & Hapus ────────────────────────────────────────

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelect(dynamic id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAllOrNone() {
    setState(() {
      if (_selectedIds.length == _filteredList.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_filteredList.map((t) => t.id));
      }
    });
  }

  /// Hapus 1 transaksi
  Future<void> _delete(dynamic id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Hapus Transaksi', style: TextStyle(color: AppColors.textPrimary)),
      content: Text('Yakin ingin menghapus transaksi ini? Saldo dompet akan disesuaikan kembali.',
          style: TextStyle(color: AppColors.textSecond, fontSize: 13, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: Text('Hapus', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700))),
      ],
    ));
    if (ok != true) return;
    try {
      await ApiService.deleteTransaksi(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Transaksi berhasil dihapus'),
        duration: Duration(seconds: 2),
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal menghapus: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  /// Hapus transaksi yang dipilih (Multi-Select)
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Hapus $count Transaksi?', style: TextStyle(color: AppColors.textPrimary)),
      content: Text(
        'Tindakan ini akan menghapus $count transaksi yang Anda pilih secara permanen dan menyesuaikan saldo dompet terkait.',
        style: TextStyle(color: AppColors.textSecond, fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus Pilihan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
    if (ok != true) return;

    setState(() => _isDeleting = true);
    try {
      final idsToDelete = _selectedIds.toList();
      await ApiService.deleteTransaksiBatch(idsToDelete);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count transaksi berhasil dihapus'),
        backgroundColor: AppColors.success,
      ));
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal menghapus beberapa transaksi: $e'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// Hapus semua transaksi
  Future<void> _deleteAllTransaksi() async {
    if (_list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tidak ada transaksi untuk dihapus'),
      ));
      return;
    }

    final total = _list.length;
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Hapus SEMUA Transaksi?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        ),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Tindakan ini akan MENGHAPUS SELURUH data transaksi ($total transaksi) secara permanen dari perangkat dan cloud.',
          style: TextStyle(color: AppColors.textSecond, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.danger.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: AppColors.danger, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Perubahan ini tidak dapat dibatalkan.',
                style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600))),
          ]),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus Semua', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
    if (ok != true) return;

    setState(() => _isDeleting = true);
    try {
      await ApiService.deleteAllTransaksi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Semua data transaksi berhasil dibersihkan'),
        backgroundColor: AppColors.success,
      ));
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal menghapus semua transaksi: $e'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // Group transaksi by date
  Map<String, List<Transaksi>> get _grouped {
    final map = <String, List<Transaksi>>{};
    for (final tx in _filteredList) {
      final date = tx.tanggal.length > 10 ? tx.tanggal.substring(0, 10) : tx.tanggal;
      map.putIfAbsent(date, () => []).add(tx);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Header / Selection Bar ──────────────────────────────
          if (_isSelectionMode)
            _buildSelectionHeader()
          else
            _buildNormalHeader(),

          // ── Search & Filter Bar ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _filterBtn('Buka filter', Icons.tune, _openFilter),
              const SizedBox(width: 8),
              if (!_isSelectionMode)
                _filterBtn('Pilih', Icons.checklist_rtl_rounded, _toggleSelectionMode),
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
          if (_loading || _isDeleting)
            Expanded(child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: AppColors.primary),
                if (_isDeleting) ...[
                  const SizedBox(height: 12),
                  Text('Menghapus transaksi...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ]),
            ))
          else
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.bgCard,
                onRefresh: _load,
                child: _filteredList.isEmpty && _list.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          Text('Belum ada transaksi', style: TextStyle(color: AppColors.textMuted)),
                        ]),
                      )
                    : _filteredList.isEmpty
                        ? Center(
                            child: Text('Tidak ada transaksi yang cocok dengan filter',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 13)))
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: _grouped.entries.map((e) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(formatTanggal(e.key),
                                          style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                      Text('${e.value.length} transaksi',
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                    ],
                                  ),
                                ),
                                ...e.value.map((tx) {
                                  final isSelected = _selectedIds.contains(tx.id);
                                  return Stack(
                                    children: [
                                      TransaksiTile(
                                        tx: tx,
                                        selectable: _isSelectionMode,
                                        isSelected: isSelected,
                                        onSelectChanged: (_) => _toggleSelect(tx.id),
                                        onTap: () => _editTransaksi(tx),
                                        onDelete: () {
                                          if (!_isSelectionMode) {
                                            // Long press bisa langsung opsi pilih atau hapus
                                            _showSingleOptionSheet(tx);
                                          } else {
                                            _toggleSelect(tx.id);
                                          }
                                        },
                                      ),
                                      if (!tx.synced && !_isSelectionMode)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.warning.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                                            ),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              Icon(Icons.cloud_upload_outlined,
                                                  size: 10, color: AppColors.warning),
                                              const SizedBox(width: 3),
                                              Text('Sync',
                                                  style: TextStyle(
                                                      color: AppColors.warning,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600)),
                                            ]),
                                          ),
                                        ),
                                    ],
                                  );
                                }),
                              ],
                            )).toList(),
                          ),
              ),
            ),

          // ── Bottom Action Bar saat Mode Seleksi ──────────────────
          if (_isSelectionMode)
            _buildSelectionBottomBar(),
        ]),
      ),
    );
  }

  Widget _buildNormalHeader() {
    return ResponsiveContainer(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Transaksi',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
              child: _headerIcon(Icons.calendar_month_outlined),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const LaporanScreen())),
              child: _headerIcon(Icons.bar_chart),
            ),
            const SizedBox(width: 8),
            _headerIcon(Icons.schedule, onTap: _bukaRiwayatOtomatis),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              color: AppColors.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              icon: _headerIcon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'select') {
                  _toggleSelectionMode();
                } else if (val == 'delete_all') {
                  _deleteAllTransaksi();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'select',
                  child: Row(children: [
                    Icon(Icons.checklist_rtl_rounded, size: 18, color: AppColors.textPrimary),
                    const SizedBox(width: 10),
                    Text('Pilih Transaksi', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete_all',
                  child: Row(children: [
                    Icon(Icons.delete_sweep_outlined, size: 18, color: AppColors.danger),
                    const SizedBox(width: 10),
                    Text('Hapus Semua Transaksi',
                        style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ),
          ]),
        ]),
        const SizedBox(height: 6),
        Text('Kelola transaksi, filter multi-dompet, dan hapus riwayat.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 12),

        // Info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
              ),
            ]),
            const SizedBox(height: 10),
            const Text('Lihat semuanya di satu tempat',
                style: TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
                'Pasang filter untuk menarik transaksi dari dompet mana pun — ketuk untuk edit, tekan lama untuk opsi cepat/seleksi.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
          ]),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildSelectionHeader() {
    final allSelected = _filteredList.isNotEmpty && _selectedIds.length == _filteredList.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _toggleSelectionMode,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.close, size: 20, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${_selectedIds.length} Dipilih',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            Text('${_filteredList.length} transaksi ditampilkan',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
        TextButton.icon(
          onPressed: _selectAllOrNone,
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 16, color: AppColors.primary),
          label: Text(allSelected ? 'Batal Semua' : 'Pilih Semua',
              style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildSelectionBottomBar() {
    final count = _selectedIds.length;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count == 0 ? 'Pilih transaksi yang ingin dihapus' : '$count transaksi dipilih',
                style: TextStyle(
                  color: count == 0 ? AppColors.textMuted : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (count > 0)
                Text('Saldo akan dipulihkan otomatis',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: count == 0 ? AppColors.bgElevated : AppColors.danger,
            foregroundColor: count == 0 ? AppColors.textMuted : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: count == 0 ? null : _deleteSelected,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text('Hapus ($count)', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  /// Sheet opsi saat menekan lama salah satu transaksi
  void _showSingleOptionSheet(Transaksi tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(tx.deskripsi.isEmpty ? tx.kategori : tx.deskripsi,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
              Text('Rp ${formatAmount(tx.nominal)} · ${formatTanggalShort(tx.tanggal)}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                ),
                title: Text('Edit Transaksi', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _editTransaksi(tx);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.checklist_rtl_rounded, color: AppColors.primary, size: 20),
                ),
                title: Text('Pilih Transaksi (Multi-select)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isSelectionMode = true;
                    _selectedIds.add(tx.id);
                  });
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                ),
                title: Text('Hapus Transaksi Ini', style: TextStyle(color: AppColors.danger, fontSize: 14, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  _delete(tx.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIcon(IconData icon, {VoidCallback? onTap}) {
    final kotak = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Icon(icon, color: AppColors.textSecond, size: 18),
    );
    if (onTap == null) return kotak;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: kotak,
    );
  }

  void _bukaRiwayatOtomatis() {
    final otomatis = _list
        .where((t) => t.metodePembayaran.toLowerCase().contains('auto'))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Auto-catat dari notifikasi',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  otomatis.isEmpty
                      ? 'Belum ada transaksi yang tercatat otomatis. Aktifkan di Lainnya → Auto-catat dari notifikasi.'
                      : '${otomatis.length} transaksi tercatat otomatis.',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12, height: 1.4)),
              const SizedBox(height: 12),
              if (otomatis.isNotEmpty) ...[
                ...otomatis.take(8).map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Icon(Icons.notifications_active_outlined,
                            size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                t.deskripsi.isEmpty ? t.kategori : t.deskripsi,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13))),
                        Text('Rp ${formatAmount(t.nominal)}',
                            style: TextStyle(
                                color: t.jenis == 'pemasukan'
                                    ? AppColors.income
                                    : AppColors.expense,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                    )),
              ],
              const SizedBox(height: 8),
            ]),
      )),
    );
  }

  Widget _filterBtn(String label, IconData icon, VoidCallback onTap,
          {bool active = false}) =>
      GestureDetector(
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
            Text(label,
                style: TextStyle(
                    color: active ? Colors.white : AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: currentType == type ? color : color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(icon,
            size: 14, color: currentType == type ? Colors.white : color),
      ),
    );
  }
}