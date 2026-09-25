import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Goal> _goals = [];
  bool _loading = true;

  static final _prioColors = {'tinggi': AppColors.danger, 'sedang': AppColors.warning, 'rendah': AppColors.success};
  static const _prioLabels = {'tinggi': '🔴 Tinggi', 'sedang': '🟡 Sedang', 'rendah': '🟢 Rendah'};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getGoals();
      setState(() { _goals = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      title:  Text('Hapus Goal', style: TextStyle(color: AppColors.textPrimary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child:  Text('Batal', style: TextStyle(color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true), child:  Text('Hapus', style: TextStyle(color: AppColors.danger))),
      ],
    ));
    if (ok == true) { await ApiService.deleteGoal(id); _load(); }
  }

  void _showProgressModal(Goal g) {
    String tambah = '';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(_).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Tambah Dana ke "${g.nama}"', style:  TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(
            keyboardType: TextInputType.number,
            style:  TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(hintText: '100.000', hintStyle:  TextStyle(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.bgElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide:  BorderSide(color: AppColors.glassBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide:  BorderSide(color: AppColors.glassBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide:  BorderSide(color: AppColors.primary))),
            onChanged: (v) => tambah = v,
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              final t = double.tryParse(tambah.replaceAll(RegExp(r'\D'), '')) ?? 0;
              await ApiService.updateProgres(g.id, t);
              Navigator.pop(context); _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          )),
        ]),
      ),
    );
  }

  void _showAddModal() {
    String nama = '', target = '', nabung = '', deadline = '', prioritas = 'sedang', catatan = '';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
           Text('Buat Goal Baru', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _field('Nama Goal', 'Liburan ke Bali...', (v) => nama = v),
          _field('Target (Rp)', '5.000.000', (v) => target = v, number: true),
          _field('Nabung/Bulan (Rp, opsional)', '500.000', (v) => nabung = v, number: true),
          _field('Deadline (YYYY-MM-DD, opsional)', '2026-12-31', (v) => deadline = v),
           Text('PRIORITAS', style: TextStyle(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: _prioColors.keys.map((p) => Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => ss(() => prioritas = p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: prioritas == p ? _prioColors[p]!.withOpacity(0.15) : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: prioritas == p ? _prioColors[p]! : AppColors.glassBorder)),
                child: Text(_prioLabels[p]!, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: prioritas == p ? _prioColors[p] : AppColors.textMuted, fontWeight: FontWeight.w600)),
              ),
            ),
          ))).toList()),
          const SizedBox(height: 12),
          _field('Catatan (opsional)', 'Impian liburan...', (v) => catatan = v, multiline: true),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              if (nama.isEmpty || target.isEmpty) return;
              await ApiService.createGoal({
                'nama': nama, 'target': double.tryParse(target.replaceAll(RegExp(r'\D'), '')) ?? 0,
                'nabung_per_bulan': double.tryParse(nabung.replaceAll(RegExp(r'\D'), '')) ?? 0,
                if (deadline.isNotEmpty) 'deadline': deadline,
                'prioritas': prioritas, 'catatan': catatan,
              });
              Navigator.pop(context); _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: const Text('Buat Goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(height: 8),
        ])),
      )),
    );
  }

  Widget _field(String label, String hint, Function(String) onChange, {bool number = false, bool multiline = false}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style:  TextStyle(color: AppColors.textSecond, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        keyboardType: number ? TextInputType.number : TextInputType.text,
        maxLines: multiline ? 3 : 1,
        style:  TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(hintText: hint, hintStyle:  TextStyle(color: AppColors.textMuted),
          filled: true, fillColor: AppColors.bgElevated,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide:  BorderSide(color: AppColors.glassBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide:  BorderSide(color: AppColors.glassBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide:  BorderSide(color: AppColors.primary))),
        onChanged: onChange,
      ),
      const SizedBox(height: 12),
    ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title:  Text('Tabungan & Goals', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add, color: Colors.white, size: 20)),
            onPressed: _showAddModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
        ?  Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(
            color: AppColors.primary, backgroundColor: AppColors.bgCard, onRefresh: _load,
            child: _goals.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🏆', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                   Text('Belum ada goals', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                   Text('Tetapkan tujuan tabunganmu!', style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _showAddModal,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    child: const Text('+ Buat Goal')),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _goals.length,
                  itemBuilder: (_, i) {
                    final g = _goals[i];
                    final prioColor = _prioColors[g.prioritas] ?? AppColors.warning;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.glassBorder)),
                      child: Column(children: [
                        Row(children: [
                          // Circle progress
                          SizedBox(width: 70, height: 70, child: Stack(alignment: Alignment.center, children: [
                            CircularProgressIndicator(
                              value: g.persen / 100, strokeWidth: 6, strokeCap: StrokeCap.round,
                              backgroundColor: AppColors.bgElevated,
                              valueColor: AlwaysStoppedAnimation(g.tercapai ? AppColors.success : prioColor)),
                            Text('${g.persen.toStringAsFixed(0)}%', style: TextStyle(color: g.tercapai ? AppColors.success : prioColor, fontSize: 13, fontWeight: FontWeight.w800)),
                          ])),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.nama, style:  TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(_prioLabels[g.prioritas] ?? '', style:  TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            if (g.deadline != null) Text('📅 ${g.deadline}', style:  TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ])),
                          GestureDetector(onTap: () => _delete(g.id),
                            child: Container(padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child:  Icon(Icons.delete_outline, size: 16, color: AppColors.danger))),
                        ]),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                             Text('Terkumpul', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            CurrencyText(g.terkumpul, short: true, fontSize: 13, fontWeight: FontWeight.w700,
                              color: g.tercapai ? AppColors.success : AppColors.textPrimary),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                             Text('Target', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            CurrencyText(g.target, short: true, fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecond),
                          ]),
                        ]),
                        const SizedBox(height: 8),
                        AppProgressBar(value: g.persen, color: g.tercapai ? AppColors.success : null),
                        if (g.nabungPerBulan > 0) ...[
                          const SizedBox(height: 10),
                          Row(children: [
                             Icon(Icons.savings_outlined, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('Nabung ', style:  TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            CurrencyText(g.nabungPerBulan, short: true, fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                             Text('/bulan', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ]),
                        ],
                        if (g.tercapai) ...[
                          const SizedBox(height: 10),
                          Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                            child:  Text('🎉 Goal Tercapai!', textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700))),
                        ] else ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _showProgressModal(g),
                            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                              child:  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('Tambah Dana', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                              ])),
                          ),
                        ],
                      ]),
                    );
                  },
                ),
          ),
    );
  }
}
