import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../services/api_service.dart';

/// Scan struk → OCR AI → preview → simpan sebagai transaksi.
/// Mengembalikan `true` lewat Navigator.pop kalau ada transaksi tersimpan.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();

  Uint8List? _imageBytes;
  String _mimeType = 'image/jpeg';

  bool _scanning = false;
  bool _saving = false;
  String? _error;
  String? _info;

  // Hasil scan (editable)
  Map<String, dynamic>? _hasil;
  final _nominalCtrl = TextEditingController();
  final _deskripsiCtrl = TextEditingController();
  String _kategori = 'Lainnya';
  String _metode = 'tunai';
  String _jenis = 'pengeluaran';
  DateTime _tanggal = DateTime.now();
  List<Map<String, dynamic>> _items = [];

  @override
  void dispose() {
    _nominalCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  // ── Ambil gambar ───────────────────────────────────────────────────────────
  Future<void> _pick(ImageSource source) async {
    setState(() { _error = null; _info = null; });
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final mime = _guessMime(file.name);

      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _mimeType = mime;
        _hasil = null;
      });
      await _scan();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal mengambil gambar: $e');
    }
  }

  String _guessMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  // ── Kirim ke backend untuk OCR ─────────────────────────────────────────────
  Future<void> _scan() async {
    final bytes = _imageBytes;
    if (bytes == null) return;

    setState(() { _scanning = true; _error = null; _info = null; });
    try {
      final data = await ApiService.scanStruk(base64Encode(bytes), _mimeType);
      if (!mounted) return;

      final nominal = (data['nominal'] as num?)?.toDouble() ?? 0;
      final items = (data['items'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];

      setState(() {
        _hasil = data;
        _jenis = (data['jenis'] ?? 'pengeluaran').toString();
        _nominalCtrl.text = nominal > 0 ? nominal.toStringAsFixed(0) : '';
        _deskripsiCtrl.text = (data['deskripsi'] ?? '').toString();
        _kategori = _matchKategori((data['kategori'] ?? '').toString());
        _metode = _matchMetode((data['metode_pembayaran'] ?? 'tunai').toString());
        _tanggal = DateTime.tryParse((data['tanggal'] ?? '').toString()) ?? DateTime.now();
        _items = items;
        _scanning = false;
      });

      final conf = data['confidence'];
      if (nominal <= 0) {
        setState(() => _error = 'Total tidak terbaca. Cek lagi nominalnya di bawah.');
      } else if (conf is num && conf < 0.5) {
        setState(() => _info = 'Hasil kurang yakin — mohon periksa nominal & toko.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = _prettyError(e);
      });
    }
  }

  String _prettyError(Object e) {
    final s = e.toString();
    final m = RegExp(r'"error"\s*:\s*"([^"]+)"').firstMatch(s);
    if (m != null) return m.group(1)!;
    if (s.contains('unauthorized')) return 'Sesi habis. Silakan login ulang.';
    if (s.contains('SocketException') || s.contains('Connection')) {
      return 'Tidak bisa menghubungi server. Periksa koneksi internet.';
    }
    return 'Gagal membaca struk. Coba lagi dengan foto yang lebih jelas.';
  }

  String _matchKategori(String raw) {
    final labels = kategoriList.map((k) => k.label).toList();
    final exact = labels.where((l) => l.toLowerCase() == raw.toLowerCase());
    if (exact.isNotEmpty) return exact.first;
    final partial = labels.where((l) =>
        l.toLowerCase().contains(raw.toLowerCase()) ||
        raw.toLowerCase().contains(l.toLowerCase()));
    return partial.isNotEmpty ? partial.first : 'Lainnya';
  }

  String _matchMetode(String raw) {
    const metode = ['tunai', 'transfer', 'qris', 'debit', 'kredit'];
    final r = raw.toLowerCase();
    return metode.firstWhere((m) => r.contains(m), orElse: () => 'tunai');
  }

  // ── Simpan transaksi ───────────────────────────────────────────────────────
  Future<void> _simpan() async {
    final nominal = double.tryParse(
      _nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (nominal <= 0) {
      setState(() => _error = 'Nominal harus lebih dari 0.');
      return;
    }

    setState(() { _saving = true; _error = null; });
    try {
      await ApiService.createTransaksi({
        'jenis': _jenis,
        'nominal': nominal,
        'kategori': _kategori,
        'deskripsi': _deskripsiCtrl.text.trim().isEmpty
            ? 'Struk' : _deskripsiCtrl.text.trim(),
        'metode_pembayaran': _metode,
        'tanggal': _tanggal.toIso8601String().split('T').first,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _prettyError(e);
      });
    }
  }

  Future<void> _pickTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text('Scan Struk', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          if (_imageBytes != null && !_scanning)
            IconButton(
              tooltip: 'Scan ulang',
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecond),
              onPressed: _scan,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildImageArea(),
          const SizedBox(height: 14),
          if (_error != null) _banner(_error!, AppColors.expense, Icons.error_outline),
          if (_info != null) _banner(_info!, AppColors.warning, Icons.info_outline),
          if (_error != null || _info != null) const SizedBox(height: 14),
          if (_hasil != null && !_scanning) _buildForm(),
          if (_hasil == null && !_scanning) _buildTips(),
        ],
      ),
    );
  }

  // ── Area gambar / tombol ambil ─────────────────────────────────────────────
  Widget _buildImageArea() {
    if (_scanning) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 40, height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary)),
          SizedBox(height: 16),
          Text('Membaca struk...', style: TextStyle(
            color: AppColors.textSecond, fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('AI sedang mengekstrak total & item', style: TextStyle(
            color: AppColors.textMuted, fontSize: 11)),
        ]),
      );
    }

    if (_imageBytes == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Foto struk belanjamu', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Total, toko, tanggal, dan item dibaca otomatis',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _pickButton(
              icon: Icons.camera_alt_rounded, label: 'Kamera',
              gradient: AppColors.gradientPrimary, onTap: () => _pick(ImageSource.camera))),
            const SizedBox(width: 10),
            Expanded(child: _pickButton(
              icon: Icons.photo_library_rounded, label: 'Galeri',
              gradient: AppColors.gradientViolet, onTap: () => _pick(ImageSource.gallery))),
          ]),
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            const Text('Di web, "Kamera" memakai kamera perangkat bila diizinkan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 10.5)),
          ],
        ]),
      );
    }

    // Preview gambar hasil ambil
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 240,
          width: double.infinity,
          color: AppColors.bgCard,
          child: Image.memory(_imageBytes!, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted, size: 40))),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _pickButton(
          icon: Icons.camera_alt_rounded, label: 'Foto Ulang',
          gradient: AppColors.gradientPrimary, onTap: () => _pick(ImageSource.camera))),
        const SizedBox(width: 10),
        Expanded(child: _pickButton(
          icon: Icons.photo_library_rounded, label: 'Pilih Lain',
          gradient: AppColors.gradientViolet, onTap: () => _pick(ImageSource.gallery))),
      ]),
    ]);
  }

  Widget _pickButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  Widget _banner(String text, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(
        color: color, fontSize: 12, height: 1.4))),
    ]),
  );

  // ── Form hasil scan (editable) ─────────────────────────────────────────────
  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.gradientPrimary,
            begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        const Text('Hasil Scan', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.income.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.income.withOpacity(0.3))),
          child: const Text('AI', style: TextStyle(
            color: AppColors.income, fontSize: 10, fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 12),

      // Nominal besar
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.gradientPrimary,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_jenis == 'pemasukan' ? 'TOTAL MASUK' : 'TOTAL BAYAR',
            style: TextStyle(color: Colors.white.withOpacity(0.85),
              fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Row(children: [
            const Text('Rp ', style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            Expanded(child: TextField(
              controller: _nominalCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w800, letterSpacing: -0.5),
              decoration: const InputDecoration(
                isDense: true, border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 26)),
            )),
          ]),
        ]),
      ),
      const SizedBox(height: 12),

      _fieldCard(
        icon: Icons.storefront_rounded, label: 'Toko / Keterangan',
        child: TextField(
          controller: _deskripsiCtrl,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14,
            fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            isDense: true, border: InputBorder.none,
            hintText: 'Nama toko', hintStyle: TextStyle(color: AppColors.textHint)),
        ),
      ),
      const SizedBox(height: 10),

      // Jenis
      Row(children: [
        Expanded(child: _chip(
          label: 'Pengeluaran', selected: _jenis == 'pengeluaran',
          color: AppColors.expense,
          onTap: () => setState(() => _jenis = 'pengeluaran'))),
        const SizedBox(width: 8),
        Expanded(child: _chip(
          label: 'Pemasukan', selected: _jenis == 'pemasukan',
          color: AppColors.income,
          onTap: () => setState(() => _jenis = 'pemasukan'))),
      ]),
      const SizedBox(height: 10),

      _fieldCard(
        icon: Icons.calendar_today_rounded, label: 'Tanggal',
        onTap: _pickTanggal,
        child: Text(
          formatTanggal(_tanggal.toIso8601String().split('T').first),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14,
            fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 10),

      _fieldCard(
        icon: Icons.category_rounded, label: 'Kategori',
        child: Wrap(spacing: 6, runSpacing: 6, children: kategoriList
          .where((k) => k.label != 'Makanan')
          .map((k) => _chip(
            label: '${k.icon} ${k.label}',
            selected: _kategori == k.label,
            color: AppColors.primary,
            small: true,
            onTap: () => setState(() => _kategori = k.label)))
          .toList()),
      ),
      const SizedBox(height: 10),

      _fieldCard(
        icon: Icons.payments_rounded, label: 'Metode Pembayaran',
        child: Wrap(spacing: 6, runSpacing: 6, children:
          ['tunai', 'qris', 'debit', 'kredit', 'transfer'].map((m) => _chip(
            label: m.toUpperCase(),
            selected: _metode == m,
            color: AppColors.accent,
            small: true,
            onTap: () => setState(() => _metode = m))).toList()),
      ),

      if (_items.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.list_alt_rounded, size: 15, color: AppColors.textSecond),
              const SizedBox(width: 6),
              Text('${_items.length} item terbaca', style: const TextStyle(
                color: AppColors.textSecond, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 10),
            ..._items.take(12).map((it) {
              final harga = (it['harga'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(child: Text((it['nama'] ?? '-').toString(),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                  Text('Rp ${formatAmount(harga)}', style: const TextStyle(
                    color: AppColors.textSecond, fontSize: 12,
                    fontWeight: FontWeight.w600)),
                ]),
              );
            }),
            if (_items.length > 12)
              Text('+${_items.length - 12} item lainnya',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
      ],

      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: TextButton(
          onPressed: _saving ? null : () => setState(() {
            _hasil = null; _imageBytes = null; _items = []; _error = null; _info = null;
          }),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.glassBorder))),
          child: const Text('Batal', style: TextStyle(
            color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _saving ? null : _simpan,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.gradientIncome),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                  color: AppColors.income.withOpacity(0.3),
                  blurRadius: 12, offset: const Offset(0, 4))]),
              child: Center(child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
                    strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Simpan Transaksi', style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ])),
            ),
          ),
        )),
      ]),
    ]);
  }

  Widget _fieldCard({
    required IconData icon,
    required String label,
    required Widget child,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(label.toUpperCase(), style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      );

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    bool small = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 14, vertical: small ? 6 : 11),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.18) : AppColors.bgElevated,
            borderRadius: BorderRadius.circular(small ? 8 : 10),
            border: Border.all(
              color: selected ? color : AppColors.textMuted.withOpacity(0.15),
              width: selected ? 1.3 : 1)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            color: selected ? color : AppColors.textSecond,
            fontSize: small ? 11 : 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ),
      );

  Widget _buildTips() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.glassBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppColors.warning),
        const SizedBox(width: 6),
        const Text('Supaya hasilnya akurat', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      ...['Foto struk di tempat terang, tanpa bayangan.',
          'Pastikan baris Total / Grand Total terlihat jelas.',
          'Struk memenuhi frame, tidak terpotong.',
          'Hindari blur — tahan kamera sebentar sebelum memotret.']
        .map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('• ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            Expanded(child: Text(t, style: const TextStyle(
              color: AppColors.textSecond, fontSize: 11.5, height: 1.4))),
          ]),
        )),
    ]),
  );
}
