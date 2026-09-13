import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});
  @override State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  List<Transaksi> _list = [];
  List<Akun> _akun = [];
  String _filter = 'semua';
  bool _loading = true;

  // Form
  String _jenis = 'pengeluaran';
  String _nominal = '';
  String _deskripsi = '';
  String _tanggal = currentTanggal();
  String _kategori = 'Makanan';
  String _metode = 'tunai';
  int? _akunId;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getTransaksi(jenis: _filter == 'semua' ? null : _filter, limit: 100),
        ApiService.getAkunList(),
      ]);
      setState(() {
        _list = results[0] as List<Transaksi>;
        _akun = results[1] as List<Akun>;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: const Text('Hapus Transaksi', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('Yakin hapus?', style: TextStyle(color: AppColors.textSecond)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
      ],
    ));
    if (ok == true) { await ApiService.deleteTransaksi(id); _load(); }
  }

  Future<void> _save() async {
    if (_nominal.isEmpty) return;
    await ApiService.createTransaksi({
      'tanggal': _tanggal, 'jenis': _jenis,
      'nominal': double.tryParse(_nominal.replaceAll(RegExp(r'\D'), '')) ?? 0,
      'kategori': _kategori, 'deskripsi': _deskripsi,
      'metode_pembayaran': _metode,
      if (_akunId != null) 'akun_id': _akunId,
    });
    Navigator.pop(context);
    _load();
  }

  // Group transaksi by date
  Map<String, List<Transaksi>> get _grouped {
    final map = <String, List<Transaksi>>{};
    for (final tx in _list) {
      map.putIfAbsent(tx.tanggal, () => []).add(tx);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Transaksi', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            onPressed: _showAddModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // Filter tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            for (final f in [('semua', 'Semua'), ('pemasukan', 'Masuk'), ('pengeluaran', 'Keluar')])
              Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () { setState(() => _filter = f.$1); _load(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _filter == f.$1 ? AppColors.primary.withOpacity(0.2) : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _filter == f.$1 ? AppColors.primary : AppColors.glassBorder),
                    ),
                    child: Text(f.$2, textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _filter == f.$1 ? AppColors.primary : AppColors.textMuted,
                        fontWeight: _filter == f.$1 ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      )),
                  ),
                ),
              )),
          ]),
        ),

        // List
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
        else Expanded(
          child: RefreshIndicator(
            color: AppColors.primary, backgroundColor: AppColors.bgCard,
            onRefresh: _load,
            child: _list.isEmpty
              ? const Center(child: Text('Belum ada transaksi', style: TextStyle(color: AppColors.textMuted)))
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _grouped.entries.map((e) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(formatTanggal(e.key),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      ...e.value.map((tx) => GestureDetector(
                        onLongPress: () => _delete(tx.id),
                        child: Stack(
                          children: [
                            TransaksiTile(tx: tx),
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
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.cloud_upload_outlined, size: 10, color: AppColors.warning),
                                    SizedBox(width: 3),
                                    Text('Menunggu sync', style: TextStyle(color: AppColors.warning, fontSize: 9, fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                      )),
                    ],
                  )).toList(),
                ),
          ),
        ),
      ]),
    );
  }

  void _showAddModal() {
    _jenis = 'pengeluaran'; _nominal = ''; _deskripsi = '';
    _tanggal = currentTanggal(); _kategori = 'Makanan'; _metode = 'tunai'; _akunId = null;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Tambah Transaksi', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          // Jenis toggle
          Row(children: [
            for (final j in [('pengeluaran', '↑ Pengeluaran'), ('pemasukan', '↓ Pemasukan')])
              Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => ss(() { _jenis = j.$1; _kategori = j.$1 == 'pemasukan' ? 'Gaji' : 'Makanan'; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _jenis == j.$1
                        ? (j.$1 == 'pengeluaran' ? AppColors.danger : AppColors.success).withOpacity(0.15)
                        : AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _jenis == j.$1 ? (j.$1 == 'pengeluaran' ? AppColors.danger : AppColors.success) : AppColors.glassBorder),
                    ),
                    child: Text(j.$2, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              )),
          ]),
          const SizedBox(height: 16),

          _inputLabel('Nominal'),
          TextField(
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDec('0'),
            onChanged: (v) => _nominal = v,
          ),
          const SizedBox(height: 12),

          _inputLabel('Deskripsi'),
          TextField(
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDec('Makan siang...'),
            onChanged: (v) => _deskripsi = v,
          ),
          const SizedBox(height: 12),

          _inputLabel('Tanggal'),
          TextField(
            controller: TextEditingController(text: _tanggal),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDec('YYYY-MM-DD'),
            onChanged: (v) => _tanggal = v,
          ),
          const SizedBox(height: 12),

          _inputLabel('Kategori'),
          SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal,
            children: kategoriList.where((k) => k.label == 'Transfer' || k.label == 'Lainnya' ||
              (_jenis == 'pemasukan' ? ['Gaji','Bonus','Investasi'].contains(k.label) : !['Gaji','Bonus','Investasi'].contains(k.label))).map((k) =>
              GestureDetector(
                onTap: () => ss(() => _kategori = k.label),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kategori == k.label ? Color(k.color).withOpacity(0.2) : AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kategori == k.label ? Color(k.color) : AppColors.glassBorder),
                  ),
                  child: Text('${k.icon} ${k.label}', style: TextStyle(
                    color: _kategori == k.label ? Color(k.color) : AppColors.textMuted, fontSize: 12)),
                ),
              )).toList())),
          const SizedBox(height: 12),

          _inputLabel('Metode'),
          Wrap(spacing: 8, children: ['tunai','transfer','qris','debit','kredit'].map((m) =>
            GestureDetector(
              onTap: () => ss(() => _metode = m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _metode == m ? AppColors.primary.withOpacity(0.15) : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _metode == m ? AppColors.primary : AppColors.glassBorder),
                ),
                child: Text(m, style: TextStyle(
                  color: _metode == m ? AppColors.primary : AppColors.textMuted,
                  fontWeight: _metode == m ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
              ),
            )).toList()),
          const SizedBox(height: 16),

          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Simpan Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          )),
        ])),
      )),
    );
  }

  Widget _inputLabel(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(s.toUpperCase(), style: const TextStyle(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted),
    filled: true, fillColor: AppColors.bgElevated,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.glassBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.glassBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
