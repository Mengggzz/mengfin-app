import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum SettingsPage { kazzUtama, autoNotif }

class SettingsScreen extends StatefulWidget {
  final SettingsPage page;
  const SettingsScreen({super.key, required this.page});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Akun> _wallets = [];
  bool _loading = true;
  int? _primaryWalletId;
  Set<int> _selectedWallets = {};

  // Auto-notif state
  bool _notifEnabled = false;
  List<String> _keywords = ['pembayaran', 'transaksi', 'Rp'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final wallets = await ApiService.getAkunList();
      setState(() {
        _wallets = wallets;
        if (wallets.isNotEmpty) {
          _primaryWalletId = wallets.first.id;
          _selectedWallets = {wallets.first.id};
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
        title: Text(
          widget.page == SettingsPage.kazzUtama
              ? 'Pengaturan Kazz Utama'
              : 'Auto-catat dari notifikasi',
          style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : widget.page == SettingsPage.kazzUtama
              ? _buildKazzUtama()
              : _buildAutoNotif(),
    );
  }

  // ─── Pengaturan Kazz Utama ──────────────────────────────────
  Widget _buildKazzUtama() {
    return Column(children: [
      Expanded(child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          const Text('Pilih Kazz untuk Tampilan Home',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Anda dapat memilih beberapa untuk melihat tampilan gabungan.\n'
            'Ideal : tampilkan hanya sisa saldo yang bisa dihabiskan periode ini.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
          const SizedBox(height: 20),

          ..._wallets.map((w) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(
                  w.ikon == 'cash' ? '💵' : '💰',
                  style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w.nama, style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${w.saldo < 0 ? '-' : ''}Rp ${formatAmount(w.saldo.abs())}',
                  style: TextStyle(
                    color: w.saldo < 0 ? AppColors.expense : AppColors.textMuted,
                    fontSize: 12)),
              ])),
              // Utama radio
              if (_primaryWalletId == w.id)
                Row(children: [
                  Radio<int>(
                    value: w.id,
                    groupValue: _primaryWalletId,
                    onChanged: (v) => setState(() => _primaryWalletId = v),
                    activeColor: AppColors.primary,
                  ),
                  const Text('Utama', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ]),
              const SizedBox(width: 4),
              // Checkbox
              Checkbox(
                value: _selectedWallets.contains(w.id),
                onChanged: (v) => setState(() {
                  if (v == true) _selectedWallets.add(w.id);
                  else _selectedWallets.remove(w.id);
                }),
                activeColor: AppColors.primary,
                side: const BorderSide(color: AppColors.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ]),
          )),
        ],
      )),

      // Save button
      Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
        child: SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        )),
      ),
    ]);
  }

  // ─── Auto-catat dari Notifikasi ──────────────────────────────
  Widget _buildAutoNotif() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 8),

        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.search, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text(
              'Aktifkan dan lihat seberapa efektif fitur ini menangkap transaksimu. '
              'Tetapi mengubah draft menjadi transaksi (Scan All) memerlukan Premium.',
              style: TextStyle(color: AppColors.textSecond, fontSize: 12, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 16),

        // Toggle card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(children: [
            Icon(
              _notifEnabled ? Icons.notifications_active : Icons.notifications_off,
              color: _notifEnabled ? AppColors.primary : AppColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_notifEnabled ? 'Aktif' : 'Nonaktif',
                style: TextStyle(
                  color: _notifEnabled ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
              const Text('Izinkan Kazz membaca notifikasi dari aplikasi yang kamu pilih',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ])),
            Switch(
              value: _notifEnabled,
              onChanged: (v) => setState(() => _notifEnabled = v),
              activeColor: AppColors.primary,
              inactiveTrackColor: AppColors.bgElevated,
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // Warning
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
            const SizedBox(width: 8),
            const Expanded(child: Text(
              'Beberapa HP (mis. Xiaomi, Huawei, Oppo) suka mematikan aplikasi latar belakang demi hemat baterai. '
              'Kalau notifikasi berhenti tertangkap, cek pengaturan baterai HP kamu dan izinkan Kazz berjalan di latar belakang.',
              style: TextStyle(color: AppColors.warning, fontSize: 10, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 16),

        // Monitored apps
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(children: [
            const Icon(Icons.apps, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Aplikasi yang dipantau', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('Belum ada aplikasi dipilih', style: TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
            ])),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ]),
        ),
        const SizedBox(height: 20),

        // Keywords whitelist
        const Text('Kata kunci whitelist', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          const Expanded(child: Text(
            'Notifikasi cuma ditangkap kalau mengandung salah satu kata ini dan ada angka nominalnya.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.3))),
        ]),
        const SizedBox(height: 12),

        // Keyword chips
        Wrap(spacing: 8, runSpacing: 8, children: _keywords.map((kw) =>
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(kw, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _keywords.remove(kw)),
                child: const Icon(Icons.close, size: 14, color: AppColors.primary)),
            ]),
          )).toList()),
        const SizedBox(height: 12),

        // Add keyword
        Row(children: [
          Expanded(child: TextField(
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tambah kata kunci (mis. "berhasil")',
              hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 12),
              filled: true, fillColor: AppColors.bgElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) setState(() => _keywords.add(v.trim()));
            },
          )),
          const SizedBox(width: 8),
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ]),
        const SizedBox(height: 40),
      ],
    );
  }
}
