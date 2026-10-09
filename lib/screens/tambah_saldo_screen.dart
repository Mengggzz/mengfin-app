import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../widgets/saldo_illustrations.dart';

/// Satu tipe Saldo yang bisa ditambahkan. Dipakai layar Tambah Saldo.
class SaldoTipe {
  final String key;
  final String nama;
  final String deskripsi;
  final bool pro;

  const SaldoTipe({
    required this.key,
    required this.nama,
    required this.deskripsi,
    this.pro = false,
  });
}

const List<SaldoTipe> saldoTipes = [
  SaldoTipe(
    key: 'cashflow',
    nama: 'Saldo Cashflow',
    deskripsi: 'Kelola pemasukan dan pengeluaran harian Anda',
  ),
  SaldoTipe(
    key: 'tabungan',
    nama: 'Saldo Tabungan',
    deskripsi: 'Kelola dana tabungan Anda. Transfer ke Saldo tipe ini akan '
        'terdeteksi otomatis sebagai aktivitas menabung.',
  ),
  SaldoTipe(
    key: 'kredit',
    nama: 'Kartu Kredit',
    deskripsi: 'Lacak kartu kredit sebagai dompet liabilitas',
  ),
  SaldoTipe(
    key: 'aset',
    nama: 'Saldo Aset',
    deskripsi: 'Lacak nilai emas yang Anda miliki.',
    pro: true,
  ),
];

/// Layar pemilihan tipe Saldo — tampil sebagai daftar kartu, sama seperti
/// referensi: ikon berwarna, judul, deskripsi, lalu chevron.
///
/// Mengembalikan `true` lewat Navigator.pop kalau ada akun baru tersimpan.
class TambahSaldoScreen extends StatelessWidget {
  const TambahSaldoScreen({super.key});

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
                Text('Tambah Saldo',
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
                children: saldoTipes
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TipeSaldoCard(
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

  void _bukaForm(BuildContext context, SaldoTipe tipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FormSaldoScreen(tipe: tipe),
      ),
    ).then((hasil) {
      // Teruskan ke layar Saldo supaya daftar dompet ikut disegarkan.
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

/// Kartu satu tipe Saldo: ikon ilustrasi, judul (+ badge PRO), deskripsi.
class _TipeSaldoCard extends StatelessWidget {
  final SaldoTipe tipe;
  final VoidCallback onTap;

  const _TipeSaldoCard({required this.tipe, required this.onTap});

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
              child: SaldoIllustration(jenis: tipe.key, size: 36),
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
class _FormSaldoScreen extends StatefulWidget {
  final SaldoTipe tipe;
  const _FormSaldoScreen({required this.tipe});

  @override
  State<_FormSaldoScreen> createState() => _FormSaldoScreenState();
}

class _FormSaldoScreenState extends State<_FormSaldoScreen> {
  final _namaCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();
  final _targetNominalCtrl = TextEditingController();
  final _limitKartuCtrl = TextEditingController();
  final _tglCetakCtrl = TextEditingController();
  final _tglTempoCtrl = TextEditingController();
  final _gramCtrl = TextEditingController();
  final _hargaBeliCtrl = TextEditingController();

  DateTime? _targetTanggal;
  bool _simpan = false;
  String? _error;

  static const double kHargaEmasTerkini = 1500000; // Rp 1.500.000 / gram

  @override
  void dispose() {
    _namaCtrl.dispose();
    _saldoCtrl.dispose();
    _targetNominalCtrl.dispose();
    _limitKartuCtrl.dispose();
    _tglCetakCtrl.dispose();
    _tglTempoCtrl.dispose();
    _gramCtrl.dispose();
    _hargaBeliCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nama = _namaCtrl.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = 'Nama Saldo belum diisi.');
      return;
    }

    setState(() {
      _simpan = true;
      _error = null;
    });

    double saldo = double.tryParse(_saldoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    double? targetNominal;
    String? targetTanggal;
    double? limitKartu;
    int? tglCetak;
    int? tglTempo;
    double? gram;
    double? hargaBeli;

    if (widget.tipe.key == 'tabungan') {
      targetNominal = double.tryParse(_targetNominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
      if (_targetTanggal != null) {
        targetTanggal = '${_targetTanggal!.year}-${_targetTanggal!.month.toString().padLeft(2, '0')}-${_targetTanggal!.day.toString().padLeft(2, '0')}';
      }
    } else if (widget.tipe.key == 'kredit') {
      limitKartu = double.tryParse(_limitKartuCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
      tglCetak = int.tryParse(_tglCetakCtrl.text.trim())?.clamp(1, 28);
      tglTempo = int.tryParse(_tglTempoCtrl.text.trim())?.clamp(1, 28);
    } else if (widget.tipe.key == 'aset') {
      gram = double.tryParse(_gramCtrl.text.replaceAll(',', '.').trim());
      hargaBeli = double.tryParse(_hargaBeliCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
      if (gram != null && gram > 0) {
        saldo = gram * kHargaEmasTerkini;
      }
    }

    try {
      await ApiService.createAkun(
        nama: nama,
        jenis: widget.tipe.key,
        saldo: saldo,
        targetNominal: targetNominal,
        targetTanggal: targetTanggal,
        limitKartu: limitKartu,
        tglCetak: tglCetak,
        tglTempo: tglTempo,
        gram: gram,
        hargaBeliPerGram: hargaBeli,
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
                _label(widget.tipe.key == 'kredit'
                    ? 'NAMA KARTU'
                    : widget.tipe.key == 'aset'
                        ? 'NAMA ASET'
                        : widget.tipe.key == 'tabungan'
                            ? 'NAMA TABUNGAN'
                            : 'NAMA DOMPET / KAS'),
                const SizedBox(height: 8),
                _field(
                  controller: _namaCtrl,
                  hint: widget.tipe.key == 'kredit'
                      ? 'Contoh: Kartu Kredit BCA'
                      : widget.tipe.key == 'aset'
                          ? 'Contoh: Tabungan Emas Antam'
                          : widget.tipe.key == 'tabungan'
                              ? 'Contoh: Tabungan DP Rumah'
                              : 'Contoh: Dompet Utama',
                ),
                const SizedBox(height: 16),

                // Form spesifik per tipe
                if (widget.tipe.key == 'tabungan') ...[
                  _label('SALDO AWAL SAAT INI (Rp)'),
                  const SizedBox(height: 8),
                  _field(controller: _saldoCtrl, hint: '0', angka: true),
                  const SizedBox(height: 16),
                  _label('TARGET NOMINAL TABUNGAN (Rp)'),
                  const SizedBox(height: 8),
                  _field(controller: _targetNominalCtrl, hint: 'Contoh: 50.000.000', angka: true),
                  const SizedBox(height: 16),
                  _label('TARGET TANGGAL TERCAPAI'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _targetTanggal ?? DateTime.now().add(const Duration(days: 180)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _targetTanggal = picked);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _targetTanggal == null
                                ? 'Pilih batas tanggal target'
                                : '${_targetTanggal!.day}/${_targetTanggal!.month}/${_targetTanggal!.year}',
                            style: TextStyle(
                              color: _targetTanggal == null ? AppColors.textHint : AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ] else if (widget.tipe.key == 'kredit') ...[
                  _label('LIMIT KARTU KREDIT (Rp)'),
                  const SizedBox(height: 8),
                  _field(controller: _limitKartuCtrl, hint: 'Contoh: 15.000.000', angka: true),
                  const SizedBox(height: 16),
                  _label('TAGIHAN BERJALAN SAAT INI (Rp)'),
                  const SizedBox(height: 8),
                  _field(controller: _saldoCtrl, hint: '0', angka: true),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _label('TGL CETAK (1-28)'),
                        const SizedBox(height: 8),
                        _field(controller: _tglCetakCtrl, hint: 'Tgl 15', angka: true),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _label('TGL JATUH TEMPO (1-28)'),
                        const SizedBox(height: 8),
                        _field(controller: _tglTempoCtrl, hint: 'Tgl 5', angka: true),
                      ]),
                    ),
                  ]),
                ] else if (widget.tipe.key == 'aset') ...[
                  _label('JUMLAH BERAT EMAS (GRAM)'),
                  const SizedBox(height: 8),
                  _field(controller: _gramCtrl, hint: 'Contoh: 10.5', angka: true),
                  const SizedBox(height: 16),
                  _label('HARGA BELI PER GRAM (OPSIONAL)'),
                  const SizedBox(height: 8),
                  _field(controller: _hargaBeliCtrl, hint: 'Contoh: 1.250.000', angka: true),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estimasi harga emas acuan: Rp 1.500.000/gram. Nilai total aset akan dihitung otomatis.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                    ]),
                  ),
                ] else ...[
                  _label('SALDO AWAL (Rp)'),
                  const SizedBox(height: 8),
                  _field(controller: _saldoCtrl, hint: '0', angka: true),
                ],

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
                        : const Text('Simpan Saldo',
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
