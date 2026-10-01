import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_events.dart';
import '../services/app_prefs.dart';
import '../services/notif_service.dart';

/// Sumber daftar akun. Bisa diganti di uji supaya layar tidak perlu
/// server hidup; produksi memakai [ApiService.getAkunList].
typedef AkunFetcher = Future<List<Akun>> Function();

enum SettingsPage { kazzUtama, autoNotif }

class SettingsScreen extends StatefulWidget {
  final SettingsPage page;

  /// Produksi: `ApiService.getAkunList`. Ganti di uji supaya tidak
  /// menyentuh jaringan.
  final AkunFetcher muatAkun;

  const SettingsScreen({
    super.key,
    required this.page,
    this.muatAkun = _ApiServiceFallback.akunList,
  });
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _ApiServiceFallback {
  static Future<List<Akun>> akunList() async {
    try {
      return await ApiService.getAkunList();
    } catch (_) {
      return const [];
    }
  }
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Akun> _wallets = [];
  bool _loading = true;
  dynamic _primaryWalletId;
  Set<dynamic> _selectedWallets = {};

  // Auto-notif state
  bool _notifEnabled = false;
  List<String> _keywords = List.of(AppPrefs.kKataKunciBawaan);
  // Dipakai _pastikanIzin() untuk melacak status izin notifikasi.
  bool _izinNotif = false;

  late final TextEditingController _kataCtrl;

  @override
  void initState() {
    super.initState();
    _kataCtrl = TextEditingController();
    final prefs = AppPrefs.instance;
    _notifEnabled = prefs.notifAktif;
    _keywords = List.of(prefs.kataKunci);
    _izinNotif = prefs.notifAktif;
    _load();
  }

  @override
  void dispose() {
    _kataCtrl.dispose();
    super.dispose();
  }

  void _tambahKataKunci(String v) {
    final kata = v.trim();
    if (kata.isEmpty) return;
    // Jangan dobel kata yang sama (huruf besar/kecil dianggap sama).
    if (_keywords.any((k) => k.toLowerCase() == kata.toLowerCase())) {
      _kataCtrl.clear();
      return;
    }
    setState(() => _keywords.add(kata));
    AppPrefs.instance.setKataKunci(_keywords);
    _kataCtrl.clear();
  }

  void _hapusKataKunci(String kata) {
    setState(() => _keywords.remove(kata));
    AppPrefs.instance.setKataKunci(_keywords);
  }

  /// Buka pemilih aplikasi yang dipantau. Daftar paket diambil dari
  /// NotifService (hanya Android); di luar Android daftarnya kosong dan
  /// pengguna diberi tahu.
  Future<void> _pilihAplikasi() async {
    if (!NotifService.tersedia) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text('Pilih aplikasi yang dipantau',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          content: Text(
              'Membaca notifikasi hanya bisa di aplikasi Android. '
              'Versi web/desktop tidak bisa memantau notifikasi.',
              style: TextStyle(color: AppColors.textSecond, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    final sedang = Set<String>.from(AppPrefs.instance.appDipantau);
    final hasil = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => _PilihAplikasiDialog(sedang: sedang),
    );
    if (hasil == null) return;
    await AppPrefs.instance.setAppDipantau(hasil.toList());
    if (mounted) setState(() {});
  }

  /// Minta izin akses notifikasi kalau belum diberikan.
  Future<void> _pastikanIzin() async {
    final sudah = await NotifService.instance.izinDiberikan();
    if (sudah) {
      if (mounted) setState(() => _izinNotif = true);
      return;
    }
    final ok = await NotifService.instance.mintaIzin();
    if (!mounted) return;
    setState(() => _izinNotif = ok);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'Izin akses notifikasi belum diberikan. Ketuk lagi untuk membuka pengaturan izin.'),
        backgroundColor: AppColors.warning,
        action: SnackBarAction(
          label: 'Buka',
          onPressed: () => NotifService.instance.bukaPengaturanIzin(),
        ),
      ));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final wallets = await widget.muatAkun();
      final prefs = AppPrefs.instance;
      final utama = prefs.dompetUtama;
      final tampil = prefs.dompetTampil;
      setState(() {
        _wallets = wallets;
        if (wallets.isNotEmpty) {
          // Dompet utama dari pengaturan; kalau belum pernah dipilih, pakai
          // akun pertama. Id bisa int (lokal) atau String (server), jadi
          // bandingkan sebagai teks.
          final sudahAda = wallets.firstWhere(
            (w) => AppPrefs.idKeTeks(w.id) == utama,
            orElse: () => wallets.first,
          );
          _primaryWalletId = sudahAda.id;

          _selectedWallets = tampil
              .map((id) => wallets
                  .firstWhere((w) => AppPrefs.idKeTeks(w.id) == id,
                      orElse: () => wallets.first)
                  .id)
              .toSet();
          if (_selectedWallets.isEmpty) _selectedWallets = {sudahAda.id};
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _simpan() async {
    final prefs = AppPrefs.instance;
    await prefs.setDompetUtama(AppPrefs.idKeTeks(_primaryWalletId));
    await prefs.setDompetTampil(
        _selectedWallets.map((id) => AppPrefs.idKeTeks(id)).toList());

    if (!mounted) return;
    await NotifService.instance.terapkanPreferensi();

    // Beranda bisa perlu menyegarkan diri karena dompet tampil berubah.
    AppEvents.instance.akunBerubah();

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.page == SettingsPage.kazzUtama
              ? 'Pengaturan Kazz Utama'
              : 'Auto-catat dari notifikasi',
          style:  TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ?  Center(child: CircularProgressIndicator(color: AppColors.primary))
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
           Text('Pilih Kazz untuk Tampilan Home',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
           Text(
            'Anda dapat memilih beberapa untuk melihat tampilan gabungan.\n'
            'Ideal : tampilkan hanya sisa saldo yang bisa dihabiskan periode ini.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
          const SizedBox(height: 20),

          ..._wallets.map((w) => GestureDetector(
            // Ketuk baris = jadikan dompet utama. Sebelumnya ketuk baris
            // tidak melakukan apa-apa; cuma radio kecil yang bisa diketuk,
            // dan radio itu hilang untuk semua dompet kecuali yang aktif.
            onTap: () => setState(() {
              _primaryWalletId = w.id;
              _selectedWallets.add(w.id);
            }),
            child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                // Beri tanda jelas dompet mana yang jadi utama.
                color: _primaryWalletId == w.id
                    ? AppColors.primary.withOpacity(0.6)
                    : AppColors.glassBorder,
              ),
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
                Text(w.nama, style:  TextStyle(
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
                   Text('Utama', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
                side:  BorderSide(color: AppColors.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ]),
          ),
          )),
        ],
      )),

      // Save button
      Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
        child: SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _simpan,
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
    return Column(children: [
      Expanded(child: ListView(
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
             Expanded(child: Text(
              'Aktifkan dan lihat seberapa efektif fitur ini menangkap transaksimu. '
              'Hasil bacaan disimpan sebagai draft dulu — kamu yang memutuskan '
              'mana yang benar-benar dicatat.',
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
               Text('Izinkan Kazz membaca notifikasi dari aplikasi yang kamu pilih',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ])),
            Switch(
              value: _notifEnabled,
              onChanged: (v) async {
                setState(() => _notifEnabled = v);
                await AppPrefs.instance.setNotifAktif(v);
                await NotifService.instance.terapkanPreferensi();
                if (v && mounted) await _pastikanIzin();
              },
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
             Icon(Icons.info_outline, size: 14, color: AppColors.warning),
            const SizedBox(width: 8),
             Expanded(child: Text(
              'Beberapa HP (mis. Xiaomi, Huawei, Oppo) suka mematikan aplikasi latar belakang demi hemat baterai. '
              'Kalau notifikasi berhenti tertangkap, cek pengaturan baterai HP kamu dan izinkan Kazz berjalan di latar belakang.',
              style: TextStyle(color: AppColors.warning, fontSize: 10, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 16),

        // Keywords whitelist
         Text('Kata kunci whitelist', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
           Icon(Icons.info_outline, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
           Expanded(child: Text(
            'Notifikasi cuma ditangkap kalau mengandung salah satu kata ini dan ada angka nominalnya.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.3))),
        ]),
        const SizedBox(height: 12),

        // Add keyword — ditaruh di atas chip supaya kelihatan tanpa scroll.
        Row(children: [
          Expanded(child: TextField(
            controller: _kataCtrl,
            style:  TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tambah kata kunci (mis. "berhasil")',
              hintStyle:  TextStyle(color: AppColors.textHint, fontSize: 12),
              filled: true, fillColor: AppColors.bgElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: _tambahKataKunci,
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _tambahKataKunci(_kataCtrl.text),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
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
              Text(kw, style:  TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _hapusKataKunci(kw),
                child:  Icon(Icons.close, size: 14, color: AppColors.primary)),
            ]),
          )).toList()),
        const SizedBox(height: 20),

        // Monitored apps
        GestureDetector(
          onTap: _pilihAplikasi,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(children: [
              Icon(Icons.apps, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aplikasi yang dipantau', style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                  AppPrefs.instance.appDipantau.isEmpty
                      ? 'Semua aplikasi (belum ada filter)'
                      : '${AppPrefs.instance.appDipantau.length} aplikasi dipilih',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ])),
              Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        ],
      )),

      // Simpan — dipaku di bawah supaya selalu kelihatan dan tidak perlu
      // discroll untuk menyimpan.
      Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
        child: SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _simpan,
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
}

/// Dialog pemilih aplikasi yang dipantau.
///
/// Di Android daftarnya panjang (bisa ratusan), jadi dimuat bertahap dan
/// ada kotak cari. Daftar paket di luar Android kosong — layar sudah
/// menjelaskan hal itu sebelum sampai ke sini.
class _PilihAplikasiDialog extends StatefulWidget {
  final Set<String> sedang;
  const _PilihAplikasiDialog({required this.sedang});

  @override State<_PilihAplikasiDialog> createState() =>
      _PilihAplikasiDialogState();
}

class _PilihAplikasiDialogState extends State<_PilihAplikasiDialog> {
  List<String> _paket = [];
  bool _loading = true;
  String _cari = '';
  late final TextEditingController _cariCtrl;

  @override
  void initState() {
    super.initState();
    _cariCtrl = TextEditingController();
    _muat();
  }

  @override
  void dispose() {
    _cariCtrl.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    List<String> daftar;
    try {
      daftar = await NotifService.instance.daftarPaketTerpasang();
    } on MissingPluginException {
      // Plugin belum terpasang (mis. di web/desktop/uji) — jangan biarkan
      // indikator loading berputar selamanya.
      daftar = const [];
    } catch (_) {
      daftar = const [];
    }
    if (!mounted) return;
    setState(() {
      _paket = daftar;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final terpilih = Set<String>.from(widget.sedang);
    final hasil = _cari.isEmpty
        ? _paket
        : _paket.where((p) => p.toLowerCase().contains(_cari.toLowerCase())).toList();

    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: Text('Pilih aplikasi yang dipantau',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              'Pilih aplikasi yang notifikasinya mau dicatat. '
              'Kosong = semua aplikasi.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 8),
          TextField(
            controller: _cariCtrl,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari aplikasi...',
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 12),
              filled: true, fillColor: AppColors.bgElevated,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            ),
            onChanged: (v) => setState(() => _cari = v),
          ),
          const SizedBox(height: 8),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else if (hasil.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  _paket.isEmpty
                      ? 'Tidak bisa membaca daftar aplikasi.'
                      : 'Tidak ada yang cocok dengan pencarian.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: hasil.length,
                itemBuilder: (_, i) {
                  final p = hasil[i];
                  return CheckboxListTile(
                    value: terpilih.contains(p),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        terpilih.add(p);
                      } else {
                        terpilih.remove(p);
                      }
                    }),
                    title: Text(p,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 13)),
                    activeColor: AppColors.primary,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, terpilih),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
