import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../services/api_service.dart';
import '../services/ocr_service.dart';

enum ScanMode { struk, mutasi }

/// Scan struk / bukti transfer → OCR (Lokal ML Kit / Gemini AI) → preview → simpan transaksi.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();

  ScanMode _mode = ScanMode.struk;
  Uint8List? _imageBytes;
  String? _imagePath;
  String _mimeType = 'image/jpeg';

  bool _scanning = false;
  bool _saving = false;
  String? _error;
  String? _info;
  String _sumberOcr = 'lokal'; // 'lokal' atau 'ai'

  // Hasil scan struk tunggal (editable)
  Map<String, dynamic>? _hasil;
  final _nominalCtrl = TextEditingController();
  final _deskripsiCtrl = TextEditingController();
  String _kategori = 'Lainnya';
  String _metode = 'tunai';
  String _jenis = 'pengeluaran';
  DateTime _tanggal = DateTime.now();
  List<Map<String, dynamic>> _items = [];

  // Hasil scan bukti transfer / mutasi multi-transaksi
  List<Map<String, dynamic>> _mutasiList = [];
  final Set<int> _selectedMutasiIndices = {};

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
        _imagePath = file.path;
        _mimeType = mime;
        _hasil = null;
        _mutasiList = [];
        _selectedMutasiIndices.clear();
      });
      if (_mode == ScanMode.struk) {
        await _scanStruk(forceAi: false);
      } else {
        await _scanMutasi();
      }
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

  // ── OCR Struk (Lokal ML Kit dengan Fallback Gemini) ────────────────────────
  Future<void> _scanStruk({bool forceAi = false}) async {
    final bytes = _imageBytes;
    if (bytes == null) return;

    setState(() { _scanning = true; _error = null; _info = null; });
    try {
      Map<String, dynamic>? data;

      // 1. Coba scan lokal jika mobile dan tidak dipaksa AI
      if (!kIsWeb && !forceAi && _imagePath != null && _imagePath!.isNotEmpty) {
        try {
          final localRes = await OcrService.instance.scanFile(_imagePath!);
          final conf = (localRes['confidence'] as num?)?.toDouble() ?? 0.0;
          final nom = (localRes['nominal'] as num?)?.toDouble() ?? 0.0;
          if (conf >= 0.6 && nom > 0) {
            data = localRes;
            _sumberOcr = 'lokal';
          }
        } catch (_) {}
      }

      // 2. Fallback ke Gemini AI jika lokal gagal / kurang yakin / diminta user
      if (data == null) {
        data = await ApiService.scanStruk(base64Encode(bytes), _mimeType);
        _sumberOcr = 'ai';
      }

      if (!mounted) return;

      final nominal = (data['nominal'] as num?)?.toDouble() ?? 0;
      final items = (data['items'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];

      final conf = data['confidence'];
      setState(() {
        _hasil = data;
        _jenis = (data!['jenis'] ?? 'pengeluaran').toString();
        _nominalCtrl.text = nominal > 0 ? nominal.toStringAsFixed(0) : '';
        _deskripsiCtrl.text = (data['deskripsi'] ?? '').toString();
        _kategori = _matchKategori((data['kategori'] ?? '').toString());
        _metode = _matchMetode((data['metode_pembayaran'] ?? 'tunai').toString());
        _tanggal = DateTime.tryParse((data['tanggal'] ?? '').toString()) ?? DateTime.now();
        _items = items;
        _scanning = false;
        if (nominal <= 0) {
          _error = 'Total tidak terbaca. Periksa nominal di bawah atau coba dengan AI.';
        } else if (conf is num && conf < 0.6) {
          _info = 'Hasil kurang yakin — periksa nominal & toko.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = _prettyError(e);
      });
    }
  }

  // ── Scan Bukti Transfer / Mutasi Multi-Transaksi ───────────────────────────
  Future<void> _scanMutasi() async {
    final bytes = _imageBytes;
    if (bytes == null) return;

    setState(() {
      _scanning = true;
      _error = null;
      _info = null;
      _mutasiList = [];
      _selectedMutasiIndices.clear();
    });

    try {
      final list = await ApiService.scanMutasi(base64Encode(bytes), _mimeType);
      if (!mounted) return;

      setState(() {
        _scanning = false;
        _mutasiList = list;
        for (int i = 0; i < list.length; i++) {
          _selectedMutasiIndices.add(i);
        }
        if (list.isEmpty) {
          _error = 'Tidak ada transaksi mutasi yang terdeteksi pada screenshot ini.';
        }
      });
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

  // ── Simpan transaksi mutasi multi-pilih ────────────────────────────────────
  Future<void> _simpanMutasiTerpilih() async {
    final selected = _selectedMutasiIndices.map((i) => _mutasiList[i]).toList();
    if (selected.isEmpty) {
      setState(() => _error = 'Pilih minimal satu transaksi untuk disimpan.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      for (final tx in selected) {
        await ApiService.createTransaksi({
          'jenis': tx['jenis'] ?? 'pengeluaran',
          'nominal': (tx['nominal'] as num).toDouble(),
          'kategori': tx['kategori'] ?? 'Lainnya',
          'deskripsi': tx['deskripsi'] ?? 'Mutasi Transfer',
          'metode_pembayaran': tx['metode_pembayaran'] ?? 'transfer',
          'tanggal': tx['tanggal'] ?? _tanggal.toIso8601String().split('T').first,
        });
      }
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
          colorScheme:  ColorScheme.dark(
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
          icon:  Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, false),
        ),
        title:  Text(
          _mode == ScanMode.struk ? 'Scan Struk' : 'Scan Bukti Transfer',
          style: TextStyle(
            color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          if (_imageBytes != null && !_scanning)
            IconButton(
              tooltip: 'Scan ulang',
              icon:  Icon(Icons.refresh_rounded, color: AppColors.textSecond),
              onPressed: () => _mode == ScanMode.struk ? _scanStruk() : _scanMutasi(),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildModeSelector(),
          const SizedBox(height: 12),
          _buildImageArea(),
          const SizedBox(height: 14),
          if (_error != null) _banner(_error!, AppColors.expense, Icons.error_outline),
          if (_info != null) _banner(_info!, AppColors.warning, Icons.info_outline),
          if (_error != null || _info != null) const SizedBox(height: 14),
          if (_mode == ScanMode.struk && _hasil != null && !_scanning) _buildForm(),
          if (_mode == ScanMode.mutasi && _mutasiList.isNotEmpty && !_scanning) _buildMutasiList(),
          if (_hasil == null && _mutasiList.isEmpty && !_scanning) _buildTips(),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeTab(
              mode: ScanMode.struk,
              icon: Icons.receipt_long_rounded,
              label: 'Struk Belanja',
            ),
          ),
          Expanded(
            child: _modeTab(
              mode: ScanMode.mutasi,
              icon: Icons.receipt_rounded,
              label: 'Bukti Transfer',
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab({
    required ScanMode mode,
    required IconData icon,
    required String label,
  }) {
    final active = _mode == mode;
    return InkWell(
      onTap: () {
        if (_mode == mode) return;
        setState(() {
          _mode = mode;
          _hasil = null;
          _mutasiList = [];
          _error = null;
          _info = null;
        });
        if (_imageBytes != null) {
          if (_mode == ScanMode.struk) {
            _scanStruk();
          } else {
            _scanMutasi();
          }
        }
      },
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : AppColors.textMuted,
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
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
        child:  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
           Text('Foto struk belanjamu', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
           Text('Total, toko, tanggal, dan item dibaca otomatis',
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
             Text('Di web, "Kamera" memakai kamera perangkat bila diizinkan.',
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
            errorBuilder: (_, __, ___) =>  Center(
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
         Text('Hasil Scan', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _sumberOcr == 'lokal'
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.income.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _sumberOcr == 'lokal'
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.income.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            _sumberOcr == 'lokal' ? '⚡ Dibaca di perangkat' : '✨ Gemini AI',
            style: TextStyle(
              color: _sumberOcr == 'lokal' ? AppColors.primary : AppColors.income,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
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
          style:  TextStyle(color: AppColors.textPrimary, fontSize: 14,
            fontWeight: FontWeight.w600),
          decoration:  InputDecoration(
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
          style:  TextStyle(color: AppColors.textPrimary, fontSize: 14,
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

      if (_sumberOcr == 'lokal') ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _scanning ? null : () => _scanStruk(forceAi: true),
          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
          label: const Text('Coba dengan AI (Gemini)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          ),
        ),
      ],

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
               Icon(Icons.list_alt_rounded, size: 15, color: AppColors.textSecond),
              const SizedBox(width: 6),
              Text('${_items.length} item terbaca', style:  TextStyle(
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
                    style:  TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                  Text('Rp ${formatAmount(harga)}', style:  TextStyle(
                    color: AppColors.textSecond, fontSize: 12,
                    fontWeight: FontWeight.w600)),
                ]),
              );
            }),
            if (_items.length > 12)
              Text('+${_items.length - 12} item lainnya',
                style:  TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
              side:  BorderSide(color: AppColors.glassBorder))),
          child:  Text('Batal', style: TextStyle(
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

  // ── Form hasil scan mutasi multi-transaksi ──────────────────────────────────
  Widget _buildMutasiList() {
    final allSelected = _selectedMutasiIndices.length == _mutasiList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.gradientPrimary,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Mutasi Terdeteksi (${_mutasiList.length})',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  if (allSelected) {
                    _selectedMutasiIndices.clear();
                  } else {
                    for (int i = 0; i < _mutasiList.length; i++) {
                      _selectedMutasiIndices.add(i);
                    }
                  }
                });
              },
              child: Text(
                allSelected ? 'Batal Pilih Semua' : 'Pilih Semua',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...List.generate(_mutasiList.length, (index) {
          final tx = _mutasiList[index];
          final isSelected = _selectedMutasiIndices.contains(index);
          final isExpense = tx['jenis'] != 'pemasukan';
          final nom = (tx['nominal'] as num?)?.toDouble() ?? 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.glassBorder,
              ),
            ),
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedMutasiIndices.add(index);
                  } else {
                    _selectedMutasiIndices.remove(index);
                  }
                });
              },
              activeColor: AppColors.primary,
              title: Text(
                (tx['deskripsi'] ?? 'Transaksi').toString(),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${tx['tanggal'] ?? ''} · ${tx['kategori'] ?? 'Lainnya'} (${tx['metode_pembayaran'] ?? 'transfer'})',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              secondary: Text(
                '${isExpense ? '-' : '+'}Rp ${formatAmount(nom)}',
                style: TextStyle(
                  color: isExpense ? AppColors.expense : AppColors.income,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _mutasiList = [];
                          _selectedMutasiIndices.clear();
                          _imageBytes = null;
                        }),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: AppColors.glassBorder),
                  ),
                ),
                child: Text('Batal', style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving ? null : _simpanMutasiTerpilih,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.income,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Simpan (${_selectedMutasiIndices.length}) Transaksi',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
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
              Text(label.toUpperCase(), style:  TextStyle(
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
         Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppColors.warning),
        const SizedBox(width: 6),
         Text('Supaya hasilnya akurat', style: TextStyle(
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
             Text('• ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            Expanded(child: Text(t, style:  TextStyle(
              color: AppColors.textSecond, fontSize: 11.5, height: 1.4))),
          ]),
        )),
    ]),
  );
}
