/// Parser notifikasi → data transaksi.
///
/// Bagian ini SENGAJA murni (tanpa plugin, tanpa I/O) supaya bisa diuji
/// tanpa HP: plugin pembaca notifikasi hanya jalan di Android, jadi logika
/// penentuannya dipisah ke sini dan diuji dengan teks notifikasi sungguhan.
library;

/// Hasil pembacaan satu notifikasi.
class NotifTransaksi {
  final double nominal;
  final String jenis; // 'pengeluaran' | 'pemasukan'
  final String deskripsi;
  final String kategori;
  final String sumber; // nama paket aplikasi pengirim
  final String teks; // teks yang benar-benar dibaca

  const NotifTransaksi({
    required this.nominal,
    required this.jenis,
    required this.deskripsi,
    required this.kategori,
    required this.sumber,
    required this.teks,
  });

  @override
  String toString() =>
      'NotifTransaksi($jenis $nominal · $kategori · $deskripsi · $sumber)';
}

class NotifParser {
  NotifParser._();

  /// Kata kunci awal yang dipakai kalau pengguna belum mengubah apa pun.
  static const List<String> kataKunciAwal = [
    'pembayaran', 'transaksi', 'berhasil', 'debit', 'kredit',
    'transfer', 'qris', 'tagihan',
  ];

  /// Mode ketat: notifikasi hanya ditangkap kalau ada penanda pembayaran
  /// ATAU penanda uang masuk. Ini yang mencegah promo "diskon Rp50.000"
  /// ikut tercatat sebagai transaksi.
  static const List<String> kataWajibBayar = [
    'bayar', 'pembayaran', 'transaksi', 'transfer', 'debit', 'kredit',
    'qris', 'tagihan', 'belanja', 'top up', 'topup', 'tarik', 'setor',
    'pengeluaran', 'pembelian',
  ];

  static const List<String> kataMasuk = [
    'masuk', 'diterima', 'menerima', 'gaji', 'payroll', 'refund',
    'pengembalian', 'cashback', 'setor', 'top up berhasil', 'topup berhasil',
  ];

  /// Penanda iklan/promo. Kalau ada penanda ini DAN tidak ada penanda
  /// keberhasilan, notifikasi ditolak — inilah penyebab utama transaksi palsu.
  static const List<String> kataPromo = [
    'diskon', 'promo', 'voucher', 'kupon', 'gratis', 'hemat', 'hingga',
    'cicilan 0%', 'undian', 'menangkan', 'poin', 'cashback up to',
    'penawaran', 'buruan', 'flash sale',
  ];

  /// Penanda bahwa transaksi benar-benar terjadi.
  static const List<String> kataSukses = [
    'berhasil', 'sukses', 'telah', 'sudah', 'dilakukan', 'terbayar',
    'terkirim', 'tuntas', 'paid', 'settled', 'completed', 'berhasil dilakukan',
  ];

  /// Nama paket aplikasi yang lazim mengirim notifikasi transaksi.
  /// Dipakai sebagai usulan di layar "Aplikasi yang dipantau" — pengguna
  /// tetap bisa memilih yang lain.
  static const List<String> aplikasiUmum = [
    'com.gojek.app', 'com.grabtaxi.passenger', 'id.co.bankmandiri',
    'com.bca', 'com.bni', 'com.brd', 'id.dana', 'com.gojek.gopay',
    'com.shopee.id', 'com.tokopedia.tkpd', 'com.ovo', 'com.linkaja',
  ];

  /// Baca satu notifikasi. Kembalikan null kalau bukan transaksi.
  static NotifTransaksi? parse({
    required String title,
    required String content,
    required String packageName,
    Set<String> kataKunci = const {},
    bool wajibKataBayar = true,
    String sumberNama = '',
  }) {
    final teks = '$title $content'.trim();
    if (teks.isEmpty) return null;

    final lower = teks.toLowerCase();

    // 1) Harus mengandung salah satu kata kunci yang dipilih pengguna.
    if (kataKunci.isNotEmpty &&
        !kataKunci.any((k) => lower.contains(k.toLowerCase()))) {
      return null;
    }

    // 2) Mode ketat: harus ada penanda pembayaran atau uang masuk.
    if (wajibKataBayar &&
        !kataWajibBayar.any((k) => lower.contains(k)) &&
        !kataMasuk.any((k) => lower.contains(k))) {
      return null;
    }

    // 3) Promo tanpa penanda keberhasilan bukan transaksi.
    final adaPromo = kataPromo.any((k) => lower.contains(k));
    final adaSukses = kataSukses.any((k) => lower.contains(k));
    if (adaPromo && !adaSukses) return null;

    // 4) Harus ada nominal.
    final nominal = parseNominal(teks);
    if (nominal == null || nominal <= 0) return null;

    final jenis = tebakJenis(lower);

    return NotifTransaksi(
      nominal: nominal,
      jenis: jenis,
      deskripsi: _rapikanDeskripsi(title, content),
      kategori: tebakKategori(lower, jenis),
      sumber: sumberNama.isNotEmpty ? sumberNama : packageName,
      teks: teks,
    );
  }

  /// "Rp25.000" → 25000, "IDR 25,000.00" → 25000, "25rb" → 25000, "1,5jt" → 1500000.
  ///
  /// Kalau ada beberapa angka, yang dipakai adalah angka transaksi — bukan
  /// saldo. Urutan pilihan: angka setelah kata penanda (total/sebesar/nominal/
  /// senilai), lalu angka pertama yang punya penanda mata uang, terakhir angka
  /// pertama yang ditemukan.
  static double? parseNominal(String teks) {
    final kandidat = _kandidat(teks);
    if (kandidat.isEmpty) return null;

    const penanda = ['total', 'sebesar', 'nominal', 'senilai', 'sejumlah', 'jumlah'];
    for (final p in penanda) {
      final i = kandidat.indexWhere((k) => k.setelahPenanda == p);
      if (i >= 0) return kandidat[i].nilai;
    }
    final denganMataUang = kandidat.where((k) => k.adaMataUang);
    if (denganMataUang.isNotEmpty) return denganMataUang.first.nilai;
    return kandidat.first.nilai;
  }

  /// Awalan mata uang opsional, angka, lalu satuan yang menempel
  /// ("25rb"). Satuan yang dipisah spasi ("2 juta") dibaca terpisah di
  /// [_satuanSetelah] supaya kata biasa setelah angka ("Rp25.000 untuk")
  /// tidak salah dianggap satuan.
  static final RegExp _pola = RegExp(
    r'(?:^|[^a-z0-9])(rp|idr)[\s.]*([0-9][0-9.,]*)'
    r'|(?:^|[^a-z0-9])([\s.]*)([0-9][0-9.,]*)',
    caseSensitive: false,
  );

  static const Map<String, double> _satuan = {
    'rb': 1000, 'ribu': 1000, 'ribuan': 1000,
    'jt': 1000000, 'juta': 1000000, 'jutaan': 1000000,
    'm': 1000000000, 'miliar': 1000000000, 'b': 1000000000, 'bio': 1000000000,
  };

  /// Kata penanda boleh disela beberapa kata ("total transaksi Rp25.000"),
  /// tapi tidak lebih dari 24 karakter.
  static final RegExp _penandaSebelum = RegExp(
    r'\b(total|sebesar|nominal|senilai|sejumlah|jumlah)\b[^0-9]{0,24}$',
    caseSensitive: false,
  );

  static List<_Kandidat> _kandidat(String teks) {
    final hasil = <_Kandidat>[];
    for (final m in _pola.allMatches(teks)) {
      final adaMataUang = m.group(1) != null;
      final mentah = m.group(2) ?? m.group(4);
      if (mentah == null) continue;

      // Angka pada tanggal/jam bukan nominal ("27/09/2026", "14:30").
      final sebelum = m.start == 0 ? '' : teks[m.start - 1];
      if (sebelum == '-' || sebelum == ':' || sebelum == '/' || sebelum == '.') {
        continue;
      }
      final sisa = teks.substring(m.end);
      if (sisa.startsWith(':') || sisa.startsWith('/') || sisa.startsWith('-')) {
        continue;
      }

      var nilai = _angkaKeDouble(mentah);
      if (nilai == null) continue;

      // Satuan: menempel ("25rb") atau setelah spasi ("2 juta").
      final satuan = _satuanSetelah(m.end, sisa);
      if (satuan != null) {
        nilai *= satuan;
      } else if (sisa.isNotEmpty && _hurufAwal(sisa)) {
        // Diikuti kata lain tanpa spasi ("Tahap Rp25") → bukan nominal.
        continue;
      }

      // Tahun (1900..2100) tanpa mata uang & satuan hampir pasti tanggal.
      if (satuan == null && !adaMataUang && mentah.length == 4 &&
          nilai >= 1900 && nilai <= 2100) {
        continue;
      }
      if (nilai <= 0) continue;

      final p = _penandaSebelum.firstMatch(teks.substring(0, m.start))?.group(1);
      hasil.add(_Kandidat(
        nilai: nilai,
        adaMataUang: adaMataUang,
        setelahPenanda: p?.toLowerCase(),
      ));
    }
    return hasil;
  }

  /// Satuan tepat di belakang angka: "25rb" atau "2 juta".
  static double? _satuanSetelah(int end, String sisa) {
    final m = RegExp(r'^\s*([a-z]+)').firstMatch(sisa);
    if (m == null) return null;
    return _satuan[m.group(1)!.toLowerCase()];
  }

  static bool _hurufAwal(String s) {
    final c = s.codeUnitAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
  }

  /// "25.000" → 25000, "25,000.75" → 25000.75, "1,5" → 1.5
  static double? _angkaKeDouble(String mentah) {
    var s = mentah.replaceAll(RegExp(r'[.,]+$'), '');
    if (s.isEmpty) return null;

    final adaTitik = s.contains('.');
    final adaKoma = s.contains(',');
    String bilangan;

    if (adaTitik && adaKoma) {
      final desimal = s.lastIndexOf('.') > s.lastIndexOf(',') ? '.' : ',';
      final ribuan = desimal == '.' ? ',' : '.';
      bilangan = s.replaceAll(ribuan, '').replaceAll(desimal, '.');
    } else if (!adaTitik && !adaKoma) {
      bilangan = s;
    } else {
      final pemisah = adaTitik ? '.' : ',';
      final bagian = s.split(pemisah);
      final terakhir = bagian.last;
      // "25.000" / "1.234.567" → pemisah ribuan. "25,5" → desimal.
      if (bagian.length > 2 || terakhir.length == 3) {
        bilangan = bagian.join();
      } else {
        bilangan = '${bagian.sublist(0, bagian.length - 1).join()}.$terakhir';
      }
    }
    return double.tryParse(bilangan);
  }

  static const List<String> _kataKeluar = [
    'bayar', 'pembayaran', 'belanja', 'debit', 'tarik', 'tagihan',
    'keluar', 'pengeluaran', 'pembelian',
  ];

  static String tebakJenis(String lower) {
    final posMasuk = _posisiPertama(lower, kataMasuk);
    final posKeluar = _posisiPertama(lower, _kataKeluar);
    if (posMasuk >= 0 && (posKeluar < 0 || posMasuk < posKeluar)) {
      return 'pemasukan';
    }
    return 'pengeluaran';
  }

  static int _posisiPertama(String lower, List<String> kata) {
    var terbaik = -1;
    for (final k in kata) {
      final i = lower.indexOf(k);
      if (i >= 0 && (terbaik < 0 || i < terbaik)) terbaik = i;
    }
    return terbaik;
  }

  /// Label kategori harus sama persis dengan `kategoriList` di utils.dart,
  /// kalau tidak, ikonnya jadi kotak kosong di daftar transaksi.
  static String tebakKategori(String lower, String jenis) {
    if (jenis == 'pemasukan') {
      if (lower.contains('gaji') || lower.contains('payroll')) return 'Gaji';
      if (lower.contains('refund') || lower.contains('pengembalian') ||
          lower.contains('cashback')) {
        return 'Bonus';
      }
      return 'Transfer';
    }

    const peta = <String, List<String>>{
      'Makan & Minum': ['gofood', 'grabfood', 'shopeefood', 'resto', 'restoran',
        'makan', 'kopi', 'kafe', 'cafe', 'bakery', 'warteg', 'catering'],
      'Transportasi': ['grab', 'gojek', 'ojek', 'taksi', 'taxi', 'bensin',
        'pertamina', 'spbu', 'tol', 'parkir', 'krl', 'mrt', 'lrt', 'transjakarta',
        'bus', 'kereta', 'tiket'],
      'Belanja': ['tokopedia', 'shopee', 'lazada', 'blibli', 'indomaret',
        'alfamart', 'supermarket', 'super indo', 'belanja'],
      'Tagihan': ['pln', 'listrik', 'pdam', 'internet', 'indihome', 'telkom',
        'pulsa', 'kuota', 'tagihan', 'bpjs', 'pajak', 'iuran', 'cicilan'],
      'Kesehatan': ['apotek', 'klinik', 'rumah sakit', 'dokter', 'obat',
        'kimia farma'],
      'Hiburan': ['netflix', 'spotify', 'bioskop', 'cgv', 'xxi', 'game', 'steam',
        'youtube', 'vidio', 'hiburan', 'langganan'],
      'Pendidikan': ['sekolah', 'kuliah', 'kampus', 'kursus', 'buku', 'udemy'],
      'Pakaian': ['pakaian', 'baju', 'sepatu', 'uniqlo', 'zara'],
      'Perawatan': ['salon', 'barbershop', 'skincare', 'kosmetik', 'spa'],
      'Kendaraan': ['servis', 'bengkel', 'oli', 'stnk'],
      'Rumah Tangga': ['perabot', 'furniture', 'ikea', 'kebersihan', 'laundry'],
      'Sosial': ['donasi', 'sumbangan', 'zakat', 'infak', 'sedekah'],
    };
    for (final e in peta.entries) {
      if (e.value.any((k) => lower.contains(k))) return e.key;
    }
    if (lower.contains('transfer')) return 'Transfer';
    return 'Lainnya';
  }

  /// Deskripsi yang enak dibaca: judul sebagai awalan, isi dipotong.
  static String _rapikanDeskripsi(String title, String content) {
    final t = title.trim();
    final c = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    final isi = c.length > 60 ? '${c.substring(0, 57)}…' : c;
    if (t.isEmpty) return isi;
    if (isi.isEmpty) return t;
    // Banyak notifikasi mengulang judul di isinya.
    if (isi.toLowerCase().startsWith(t.toLowerCase())) return isi;
    return '$t · $isi';
  }
}

class _Kandidat {
  final double nilai;
  final bool adaMataUang;
  final String? setelahPenanda;
  const _Kandidat({
    required this.nilai,
    required this.adaMataUang,
    this.setelahPenanda,
  });
}
