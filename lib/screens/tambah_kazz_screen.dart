import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../widgets/kazz_illustrations.dart';

/// Satu tipe Kazz yang bisa ditambahkan. Dipakai layar Tambah Kazz.
class KazzTipe {
  final String key;
  final String nama;
  final String deskripsi;
  final bool pro;

  const KazzTipe({
    required this.key,
    required this.nama,
    required this.deskripsi,
    this.pro = false,
  });
}

const List<KazzTipe> kazzTipes = [
  KazzTipe(
    key: 'cashflow',
    nama: 'Kazz Cashflow',
    deskripsi: 'Kelola pemasukan dan pengeluaran harian Anda',
  ),
  KazzTipe(
    key: 'tabungan',
    nama: 'Kazz Tabungan',
    deskripsi: 'Kelola dana tabungan Anda. Transfer ke Kazz tipe ini akan '
        'terdeteksi otomatis sebagai aktivitas menabung.',
  ),
  KazzTipe(
    key: 'kredit',
    nama: 'Kartu Kredit',
    deskripsi: 'Lacak kartu kredit sebagai dompet liabilitas',
  ),
  KazzTipe(
    key: 'aset',
    nama: 'Kazz Aset',
    deskripsi: 'Lacak nilai emas yang Anda miliki.',
    pro: true,
  ),
];

/// Layar pemilihan tipe Kazz — tampil sebagai daftar kartu, sama seperti
/// referensi: ikon berwarna, judul, deskripsi, lalu chevron.
///
/// Mengembalikan `true` lewat Navigator.pop kalau ada akun baru tersimpan.
class TambahKazzScreen extends StatelessWidget {
  const TambahKazzScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                _BackButton(onTap: () => Navigator.pop(context, false)),
                const SizedBox(width: 16),
                Text('Tambah Kazz',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    )),
              ]),
            ),

            // ── Daftar tipe ───────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: kazzTipes
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TipeKazzCard(
                            tipe: t,
                            onTap: () => _bukaForm(context, t),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _bukaForm(BuildContext context, KazzTipe tipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FormKazzScreen(tipe: tipe),
      ),
    ).then((hasil) {
      // Teruskan ke layar Kazz supaya daftar dompet ikut disegarkan.
      if (hasil == true && context.mounted) Navigator.pop(context, true);
    });
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary, size: 20),
        ),
      );
}

/// Kartu satu tipe Kazz: ikon ilustrasi, judul (+ badge PRO), deskripsi.
class _TipeKazzCard extends StatelessWidget {
  final KazzTipe tipe;
  final VoidCallback onTap;

  const _TipeKazzCard({required this.tipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(children: [
          // Kotak ikon.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: KazzIllustration(jenis: tipe.key, size: 36),
            ),
          ),
          const SizedBox(width: 14),

          // Judul + deskripsi.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(tipe.nama,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                  if (tipe.pro) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('BETA • PRO',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          )),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(tipe.deskripsi,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      height: 1.35,
                    )),
              ],
            ),
          ),

          Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 22),
        ]),
      ),
    );
  }
}

/// Form isian nama + saldo awal, lalu simpan akun ke server.
class _FormKazzScreen extends StatefulWidget {
  final KazzTipe tipe;
  const _FormKazzScreen({required this.tipe});

  @override
  State<_FormKazzScreen> createState() => _FormKazzScreenState();
}

class _FormKazzScreenState extends State<_FormKazzScreen> {
  final _namaCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();
  bool _simpan = false;
  String? _error;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _saldoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nama = _namaCtrl.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = 'Nama Kazz belum diisi.');
      return;
    }

    setState(() {
      _simpan = true;
      _error = null;
    });

    final saldo =
        double.tryParse(_saldoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    try {
      await ApiService.createAkun(
        nama: nama,
        jenis: widget.tipe.key,
        saldo: saldo,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _simpan = false;
        _error = 'Gagal menyimpan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              _BackButton(onTap: () => Navigator.pop(context, false)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(widget.tipe.nama,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(widget.tipe.deskripsi,
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12, height: 1.4)),
                const SizedBox(height: 20),
                _label('NAMA KAZZ'),
                const SizedBox(height: 8),
                _field(
                  controller: _namaCtrl,
                  hint: widget.tipe.key == 'kredit'
                      ? 'Kartu Kredit BCA'
                      : 'Dompet Utama',
                ),
                const SizedBox(height: 16),
                _label(widget.tipe.key == 'kredit'
                    ? 'TAGIHAN BERJALAN (Rp)'
                    : 'SALDO AWAL (Rp)'),
                const SizedBox(height: 8),
                _field(
                  controller: _saldoCtrl,
                  hint: '0',
                  angka: true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(color: AppColors.danger, fontSize: 12)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _simpan ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _simpan
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)))
                        : const Text('Simpan Kazz',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: TextStyle(
        color: AppColors.textSecond,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool angka = false,
  }) =>
      TextField(
        controller: controller,
        keyboardType: angka ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
          filled: true,
          fillColor: AppColors.bgInput,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.glassBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.glassBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      );
}
