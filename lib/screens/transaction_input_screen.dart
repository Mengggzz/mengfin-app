import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/utils.dart';
import '../models/models.dart';
import '../services/amount_expression.dart';
import '../services/api_service.dart';
import '../services/app_prefs.dart';
import '../services/dompet_view.dart';
import '../services/kategori_otomatis.dart';
import '../widgets/widgets.dart';
import 'tambah_saldo_screen.dart';

class TransactionInputScreen extends StatefulWidget {
  final String? initialDeskripsi;

  /// Transaksi yang diedit. Null = input baru.
  final Transaksi? edit;

  const TransactionInputScreen({super.key, this.initialDeskripsi, this.edit});
  @override State<TransactionInputScreen> createState() => _TransactionInputScreenState();
}

class _TransactionInputScreenState extends State<TransactionInputScreen> {
  bool _isExpense = true; // true = pengeluaran, false = pemasukan
  String _amount = '0';
  String _deskripsi = '';
  String _kategori = 'Makan & Minum';
  String _tanggal = currentTanggal();
  TransactionType? _tipe;
  bool _saving = false;

  // Dompet: diambil dari daftar akun asli (sebelumnya tulisan mati
  // "Dompet Utama" dan transaksi tidak pernah tertaut ke akun mana pun).
  List<Akun> _akunList = [];
  dynamic _akunTerpilih;
  List<Transaksi> _riwayatCache = [];

  late final TextEditingController _deskripsiCtrl;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _deskripsi = widget.initialDeskripsi ?? '';
    _deskripsiCtrl = TextEditingController(text: _deskripsi);
    final edit = widget.edit;
    if (edit != null) {
      // Isi form dari transaksi yang ada supaya bisa dikoreksi.
      _isExpense = edit.jenis == 'pengeluaran';
      _amount = AmountExpression.formatNumber(edit.nominal);
      _deskripsi = edit.deskripsi;
      _deskripsiCtrl.text = _deskripsi;
      _tanggal = edit.tanggal.length > 10 ? edit.tanggal.substring(0, 10) : edit.tanggal;
      if (edit.kategori.isNotEmpty) _kategori = edit.kategori;
      _akunTerpilih = edit.akunId;
    }
    _muatAkun();
  }

  bool _mencariKategori = false;

  /// Ambil kategori dari transaksi terakhir dengan deskripsi mirip.
  /// Tombol ini dulu tidak melakukan apa-apa walau tertulis seolah-olah
  /// otomatis — sekarang beneran mencari.
  Future<void> _autoKategorikan() async {
    if (_mencariKategori) return;
    final deskripsi = _deskripsi.trim();
    if (deskripsi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Isi deskripsi dulu, biar dicari transaksi serupa.'),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    setState(() => _mencariKategori = true);
    try {
      final riwayat = await ApiService.getTransaksi(limit: 50);
      final tebakan = KategoriOtomatis.tebak(
        deskripsi: deskripsi, riwayat: riwayat);
      if (!mounted) return;
      if (tebakan == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Belum ada transaksi sebelumnya dengan deskripsi "$deskripsi".'),
          backgroundColor: AppColors.textMuted,
          duration: const Duration(seconds: 2),
        ));
        return;
      }
      setState(() => _kategori = tebakan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Kategori diatur ke "$tebakan".'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal mengambil riwayat: $e'),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 3),
      ));
    } finally {
      if (mounted) setState(() => _mencariKategori = false);
    }
  }

  Future<void> _muatAkun() async {
    try {
      final list = await ApiService.getAkunList();
      if (mounted && list.isNotEmpty) {
        setState(() {
          _akunList = list;
          _akunTerpilih ??= DompetView.dompetAwal(
            list, AppPrefs.instance.dompetUtama)?.id;
        });
      }
    } catch (_) {}
    try {
      final riwayat = await ApiService.getTransaksi(limit: 50);
      if (mounted) {
        _riwayatCache = riwayat;
      }
    } catch (_) {}
  }

  void _onDeskripsiChanged(String v) {
    _deskripsi = v;
    if (v.trim().isEmpty) return;
    final tebakan = KategoriOtomatis.tebak(
      deskripsi: v,
      riwayat: _riwayatCache,
      gunakanKamus: true,
      isExpense: _isExpense,
    );
    if (tebakan != null && tebakan != _kategori) {
      setState(() {
        _kategori = tebakan;
      });
    }
  }

  @override
  void dispose() {
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  void _onNumKey(String key) {
    setState(() {
      if (AmountExpression.isOperator(key)) {
        // Tidak ada yang bisa dioperasikan dari nol.
        if (_amount == '0' || _amount.isEmpty) return;
        // Operator yang menggantung digantikan, bukan ditumpuk —
        // numpad ini tidak punya tanda kurung, jadi "25 + × 10" tidak
        // mungkin dihitung. Digit yang diketik setelahnya menempel apa
        // adanya dan dihitung saat "=" ditekan.
        final dasar = AmountExpression.stripTrailingOperator(_amount);
        _amount = '$dasar $key ';
      } else {
        _amount = AmountExpression.appendDigits(_amount, key);
      }
    });
  }

  /// Angka yang akan disimpan. Ekspresi yang belum sah tidak dipaksa jadi
  /// angka: "25 +" tetap dibaca 25 supaya pengguna tidak menyimpan nominal
  /// yang tidak pernah ia lihat (dulu "25 + 10" tersimpan sebagai 2510).
  double _parseAmount() {
    final exact = AmountExpression.evaluate(_amount);
    if (exact != null) return exact > 0 ? exact : 0;
    if (AmountExpression.endsWithOperator(_amount)) {
      final last = AmountExpression.lastNumber(_amount) ?? 0;
      return last > 0 ? last : 0;
    }
    final last = AmountExpression.lastNumber(_amount) ?? 0;
    return last > 0 ? last : 0;
  }

  /// Tombol "=" : hitung ekspresi yang sedang diketik dan jadikan hasilnya
  /// isi input, supaya angka yang disimpan sama dengan yang dihitung.
  void _onEquals() {
    if (!AmountExpression.hasOperator(_amount)) return;
    final hasil = AmountExpression.evaluate(_amount);
    if (hasil == null) return; // ekspresi belum/tidak sah → biarkan apa adanya
    setState(() => _amount = AmountExpression.formatNumber(hasil));
  }

  void _onDelete() {
    setState(() {
      if (_amount.length <= 1) {
        _amount = '0';
      } else {
        _amount = _amount.substring(0, _amount.length - 1).trimRight();
        if (_amount.isEmpty) _amount = '0';
      }
    });
  }

  String? _akunNama(dynamic id) {
    for (final a in _akunList) {
      if (AppPrefs.idKeTeks(a.id) == AppPrefs.idKeTeks(id)) return a.nama;
    }
    return null;
  }

  Future<void> _pilihDompet() async {
    final terpilih = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(children: [
              Text(
                !_isExpense ? 'Saldo Masuk ke Dompet Mana?' : 'Pilih Sumber Dompet',
                style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                !_isExpense
                    ? 'Pilih dompet tujuan untuk menambahkan saldo pemasukan ini'
                    : 'Pilih dompet yang digunakan untuk transaksi ini',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
          Flexible(child: ListView(
            shrinkWrap: true,
            children: [
              if (_isExpense)
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Semua dompet'),
                  trailing: _akunTerpilih == null
                      ? Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () => Navigator.pop(context, null),
                ),
              ..._akunList.map((a) {
                final isSelected = AppPrefs.idKeTeks(a.id) == AppPrefs.idKeTeks(_akunTerpilih);
                final col = a.warna.isNotEmpty
                    ? Color(int.tryParse(a.warna.replaceFirst('#', '0xFF')) ?? 0xFF10B981)
                    : AppColors.primary;
                return ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: col.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_balance_wallet, color: col, size: 18),
                  ),
                  title: Text(a.nama, style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  subtitle: Text('Saldo: Rp ${formatAmount(a.saldo.abs())}', style: TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: AppColors.primary, size: 20) : null,
                  onTap: () => Navigator.pop(context, a.id),
                );
              }),
              ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add, color: AppColors.primaryLight, size: 20),
                ),
                title: Text('Tambah Dompet Baru', style: TextStyle(
                  color: AppColors.primaryLight, fontWeight: FontWeight.w600, fontSize: 13)),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const TambahSaldoScreen()));
                  await _muatAkun();
                },
              ),
            ],
          )),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (!mounted) return;
    if (terpilih != null || _isExpense) {
      setState(() => _akunTerpilih = terpilih);
    }
  }

  Future<void> _konfirmasiHapus() async {
    if (_saving || !_isEdit) return;
    final konfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Transaksi', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Yakin ingin menghapus transaksi ini? Saldo dompet akan disesuaikan kembali.',
          style: TextStyle(color: AppColors.textSecond, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (konfirm != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ApiService.deleteTransaksi(widget.edit!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Transaksi berhasil dihapus'),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menghapus: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onConfirm() async {
    if (_saving) return;
    final nominal = _parseAmount();
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Masukkan jumlah nominal transaksi terlebih dahulu.'),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    setState(() => _saving = true);

    // Pastikan transaksi selalu terhubung ke dompet jika daftar akun tersedia
    if (_akunTerpilih == null && _akunList.isNotEmpty) {
      if (!_isExpense) {
        await _pilihDompet();
      }
      _akunTerpilih ??= DompetView.dompetAwal(_akunList, AppPrefs.instance.dompetUtama)?.id ?? _akunList.first.id;
    }

    final body = <String, dynamic>{
      'tanggal': _tanggal,
      'jenis': _isExpense ? 'pengeluaran' : 'pemasukan',
      'nominal': nominal,
      'kategori': _kategori,
      'deskripsi': _deskripsi,
      'metode_pembayaran': 'tunai',
      if (_akunTerpilih != null) 'akun_id': _akunTerpilih,
    };
    try {
      if (_isEdit) {
        await ApiService.updateTransaksi(widget.edit!.id, body);
      } else {
        await ApiService.createTransaksi(body);
      }

      if (!_isExpense && mounted) {
        final namaDompet = _akunNama(_akunTerpilih) ?? 'Dompet';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Pemasukan ${formatRupiah(nominal)} berhasil masuk ke $namaDompet!')),
          ]),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ));
      }

      if (_isExpense && mounted) {
        // Smart Budgeting Check
        final bulan = _tanggal.substring(0, 7);
        final anggarans = await ApiService.getAnggaran(bulan);
        if (!mounted) return;
        try {
          final anggaran = anggarans.firstWhere((a) => a.kategori == _kategori);
          if (anggaran.terpakai > anggaran.batas) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Perhatian: Anggaran $_kategori bulan ini telah melebihi batas!')),
              ]),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 4),
            ));
          } else if (anggaran.terpakai >= anggaran.batas * 0.8) {
            if (!mounted) return;
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Peringatan: Anggaran $_kategori hampir habis (sisa ${formatRupiah(anggaran.batas - anggaran.terpakai)}).')),
              ]),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 4),
            ));
          }
        } catch (_) {
          // No budget set for this category, ignore
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_tanggal) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme:  ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.bgCard,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _tanggal = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isExpense ? expenseCategories : incomeCategories;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon:  Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title:  Text(_isEdit ? 'Edit Transaksi' : 'Transaksi', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (_isEdit)
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.danger),
              tooltip: 'Hapus Transaksi',
              onPressed: _saving ? null : _konfirmasiHapus,
            ),
        ],
      ),
      body: Column(children: [
        // Scrollable top section
        Expanded(child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16, right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Expense / Income Toggle ──────────────────────
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() {
                    _isExpense = true;
                    final tebakan = KategoriOtomatis.tebak(
                      deskripsi: _deskripsi,
                      riwayat: _riwayatCache,
                      gunakanKamus: true,
                      isExpense: true,
                    );
                    _kategori = tebakan ?? 'Makan & Minum';
                  }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                      color: _isExpense ? AppColors.expense : Colors.transparent,
                      width: 2,
                    )),
                  ),
                  child: Text('PENGELUARAN', textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isExpense ? AppColors.expense : AppColors.textMuted,
                      fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5)),
                ),
              )),
              Container(width: 1, height: 20, color: AppColors.divider),
              Expanded(child: GestureDetector(
                onTap: () => setState(() {
                    _isExpense = false;
                    final tebakan = KategoriOtomatis.tebak(
                      deskripsi: _deskripsi,
                      riwayat: _riwayatCache,
                      gunakanKamus: true,
                      isExpense: false,
                    );
                    _kategori = tebakan ?? 'Gaji';
                  }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                      color: !_isExpense ? AppColors.income : Colors.transparent,
                      width: 2,
                    )),
                  ),
                  child: Text('PEMASUKAN', textAlign: TextAlign.center,
                    style: TextStyle(
                      color: !_isExpense ? AppColors.income : AppColors.textMuted,
                      fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5)),
                ),
              )),
            ]),
            const SizedBox(height: 12),

            // ── Date & Wallet Row ─────────────────────────────
            Row(children: [
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                     Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(formatTanggalShort(_tanggal),
                      style:  TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              // Flexible: chip dompet dulu meluber 70px di layar 360dp ketika
              // nama dompet panjang. Ketuk → pilih dompet dari daftar akun
              // asli (dulu tulisan mati "Dompet Utama").
              Flexible(child: InkWell(
                onTap: _akunList.isEmpty ? null : _pilihDompet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: !_isExpense && _akunTerpilih == null
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: !_isExpense && _akunTerpilih != null
                        ? Border.all(color: AppColors.income.withOpacity(0.5))
                        : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(!_isExpense ? '📥 Masuk ke:' : '💰', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Flexible(child: Text(
                      _akunList.isEmpty
                          ? 'Dompet'
                          : (_akunTerpilih == null
                              ? (!_isExpense ? 'Pilih Dompet' : 'Semua dompet')
                              : (_akunNama(_akunTerpilih) ?? 'Dompet'))
                              .toString(),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: !_isExpense && _akunTerpilih != null ? AppColors.income : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ))),
                    const SizedBox(width: 4),
                     Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textMuted),
                  ]),
                ),
              )),
            ]),
            const SizedBox(height: 16),

            // ── Amount Display ─────────────────────────────────
            Center(child: Column(children: [
               Text('Jumlah', style: TextStyle(
                color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('IDR ', style: TextStyle(
                  color: _isExpense ? AppColors.expense : AppColors.income,
                  fontSize: 16, fontWeight: FontWeight.w600)),
                Flexible(child: Text(
                  // Kalau sedang mengetik ekspresi ("25 + 10"), tampilkan apa
                  // adanya supaya pengguna melihat persis yang ia ketik.
                  AmountExpression.hasOperator(_amount)
                      ? _amount.trimRight()
                      : formatAmount(_parseAmount()),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isExpense ? AppColors.expense : AppColors.income,
                    fontSize: 36, fontWeight: FontWeight.w800),
                )),
              ]),
            ])),
            const SizedBox(height: 12),

            // ── Description Field ──────────────────────────────
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               Text('Deskripsi (Opsional)', style: TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(
                  controller: _deskripsiCtrl,
                  style:  TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'kopi, bensin, gaji...',
                    hintStyle:  TextStyle(color: AppColors.textHint),
                    filled: true, fillColor: AppColors.bgElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  ),
                  onChanged: _onDeskripsiChanged,
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  // Tombol ini dulu cuma ikon hiasan. Sekarang baca kategori
                  // dari transaksi terakhir yang deskripsinya mirip.
                  onTap: _autoKategorikan,
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _mencariKategori
                          ? AppColors.primary.withOpacity(0.3)
                          : AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _mencariKategori
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                          )
                        : Icon(Icons.auto_fix_high,
                            color: AppColors.primary, size: 18),
                  ),
                ),
                ]),
              const SizedBox(height: 4),
               Text('✦ Otomatis kategorikan dari transaksi terakhir',
                style: TextStyle(color: AppColors.textHint, fontSize: 10)),
            ]),
            const SizedBox(height: 14),

            // ── Category Grid ──────────────────────────────────
            CategoryIconGrid(
              categories: categories,
              selectedCategory: _kategori,
              onSelected: (v) => setState(() => _kategori = v),
            ),
            const SizedBox(height: 14),

            // ── Type Tags (Need/Want/Saving) ───────────────────
            if (_isExpense) ...[
               Text('TIPE', style: TextStyle(
                color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              TransactionTypeSelector(
                selected: _tipe,
                onSelected: (t) => setState(() => _tipe = _tipe == t ? null : t),
              ),
              const SizedBox(height: 8),
            ],
          ]),
        )),

        // ── Amount display above numpad ──────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: AppColors.numpadBg,
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Flexible(child: Text(
              // Hasil hitung sementara. Kalau ekspresi belum lengkap, yang
              // ditampilkan angka terakhir yang sudah diketik.
              '= ${formatAmount(_parseAmount())}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecond, fontSize: 14))),
          ]),
        ),

        // ── Calculator Numpad ─────────────────────────────────
        CalcNumpad(
          onKey: _onNumKey,
          onDelete: _onDelete,
          onConfirm: _onConfirm,
          onEquals: _onEquals,
          isSaving: _saving,
        ),

        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
    );
  }
}
