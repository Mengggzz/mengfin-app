import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';

class AnggaranScreen extends StatefulWidget {
  const AnggaranScreen({super.key});
  @override State<AnggaranScreen> createState() => _AnggaranScreenState();
}

class _AnggaranScreenState extends State<AnggaranScreen> {
  List<Anggaran> _list = [];
  String _periode = currentBulan();
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getAnggaran(_periode);
      setState(() { _list = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _changeMonth(int delta) {
    final parts = _periode.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]) + delta);
    setState(() => _periode = '${dt.year}-${dt.month.toString().padLeft(2, '0')}');
    _load();
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: const Text('Hapus Anggaran', style: TextStyle(color: AppColors.textPrimary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
      ],
    ));
    if (ok == true) { await ApiService.deleteAnggaran(id); _load(); }
  }

  void _showAddModal({Anggaran? edit}) {
    String kategori = edit?.kategori ?? 'Makanan';
    String batas = edit != null ? edit.batas.toStringAsFixed(0) : '';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(edit != null ? 'Edit Anggaran' : 'Buat Anggaran',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          if (edit == null) ...[
            const Text('KATEGORI', style: TextStyle(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal,
              children: kategoriList.where((k) => !['Gaji','Bonus','Investasi'].contains(k.label)).map((k) =>
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

          const Text('BATAS ANGGARAN (Rp)', style: TextStyle(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: batas),
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '1.500.000', hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.bgElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.glassBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.glassBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
            ),
            onChanged: (v) => batas = v,
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              final b = double.tryParse(batas.replaceAll(RegExp(r'\D'), '')) ?? 0;
              if (edit != null) { await ApiService.updateAnggaran(edit.id, b); }
              else { await ApiService.createAnggaran(kategori, b, _periode); }
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
    final totalBatas = _list.fold(0.0, (s, a) => s + a.batas);
    final totalTerpakai = _list.fold(0.0, (s, a) => s + a.terpakai);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Anggaran', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add, color: Colors.white, size: 20)),
            onPressed: () => _showAddModal(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary, backgroundColor: AppColors.bgCard, onRefresh: _load,
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          // Month picker
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left, color: AppColors.textSecond)),
            Text(formatBulan(_periode), style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right, color: AppColors.textSecond)),
          ]),
          const SizedBox(height: 4),

          // Summary
          GlassCard(
            gradient: const LinearGradient(colors: AppColors.gradientPrimary, begin: Alignment.topLeft, end: Alignment.bottomRight),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Anggaran', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              CurrencyText(totalBatas, fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
              const SizedBox(height: 8),
              AppProgressBar(value: totalBatas > 0 ? (totalTerpakai / totalBatas * 100) : 0, color: Colors.white70),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Terpakai ${totalBatas > 0 ? (totalTerpakai / totalBatas * 100).toStringAsFixed(0) : 0}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                CurrencyText(totalBatas - totalTerpakai, short: true, color: Colors.white70, fontSize: 12),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_list.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: Column(children: [
              const Text('📊', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('Belum ada anggaran', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => _showAddModal(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('+ Buat Anggaran')),
            ])))
          else ..._list.map((a) {
            final kat = getKategoriInfo(a.kategori);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(width: 38, height: 38,
                      decoration: BoxDecoration(color: Color(kat.color).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text(kat.icon, style: const TextStyle(fontSize: 18)))),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.kategori, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                      Row(children: [
                        CurrencyText(a.terpakai, short: true, color: AppColors.textMuted, fontSize: 12),
                        const Text(' / ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        CurrencyText(a.batas, short: true, color: AppColors.textMuted, fontSize: 12),
                      ]),
                    ]),
                  ]),
                  Row(children: [
                    GestureDetector(onTap: () => _showAddModal(edit: a),
                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted))),
                    const SizedBox(width: 6),
                    GestureDetector(onTap: () => _delete(a.id),
                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger))),
                  ]),
                ]),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: AppProgressBar(value: a.persentase, height: 10)),
                  const SizedBox(width: 10),
                  Text('${a.persentase.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: a.persentase >= 100 ? AppColors.danger : a.persentase >= 80 ? AppColors.warning : AppColors.success)),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
