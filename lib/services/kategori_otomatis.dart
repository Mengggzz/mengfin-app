import '../models/models.dart';

/// Tebak kategori transaksi dari riwayat pengguna dan kamus kata kunci cerdas.
class KategoriOtomatis {
  KategoriOtomatis._();

  static const int _maksHari = 30;
  static const int _minKata = 3;

  /// Tebak kategori untuk [deskripsi].
  ///
  /// [riwayat] jika diberikan akan diprioritaskan dari yang paling baru.
  /// [gunakanKamus] jika true akan mencocokkan dengan kamus kata kunci otomatis.
  static String? tebak({
    required String deskripsi,
    List<Transaksi>? riwayat,
    bool gunakanKamus = false,
    bool isExpense = true,
  }) {
    final teks = deskripsi.trim().toLowerCase();
    if (teks.isEmpty) return null;

    // 1. Coba cocokkan dari riwayat transaksi terdahulu (maks 30 hari)
    if (riwayat != null && riwayat.isNotEmpty) {
      final kataKunci = _kataPenting(teks);
      if (kataKunci.isNotEmpty) {
        final batas = DateTime.now().subtract(const Duration(days: _maksHari));

        for (final tx in riwayat) {
          final tgl = DateTime.tryParse(tx.tanggal);
          if (tgl == null || tgl.isBefore(batas)) continue;

          final riwayatTeks = tx.deskripsi.trim().toLowerCase();
          if (riwayatTeks.isEmpty) continue;

          if (_cocok(teks, riwayatTeks, kataKunci)) {
            return tx.kategori;
          }
        }
      }
    }

    // 2. Jika gunakanKamus aktif, tebak berdasarkan kamus kata kunci bawaan
    if (gunakanKamus) {
      return tebakKamus(teks, isExpense: isExpense);
    }

    return null;
  }

  /// Tebak kategori dari kamus kata kunci Indonesia & istilah umum.
  static String? tebakKamus(String deskripsi, {bool isExpense = true}) {
    final teks = deskripsi.trim().toLowerCase();
    if (teks.isEmpty) return null;

    if (!isExpense) {
      // Kamus Pemasukan
      if (_matches(teks, const [
        'gaji', 'salary', 'upah', 'payroll', 'honor', 'thr', 'gajian', 'tunjangan'
      ])) {
        return 'Gaji';
      }
      if (_matches(teks, const [
        'bonus', 'insentif', 'komisi', 'tips', 'angpao', 'hadiah', 'reward',
        'cashback', 'giveaway', 'sawer'
      ])) {
        return 'Bonus';
      }
      if (_matches(teks, const [
        'dividen', 'saham', 'reksadana', 'crypto', 'bunga', 'deposito',
        'cuan', 'profit', 'trading', 'investasi', 'yield'
      ])) {
        return 'Investasi';
      }
      if (_matches(teks, const [
        'transfer', 'kiriman', 'tf masuk', 'dari', 'pengembalian', 'refund', 'topup'
      ])) {
        return 'Transfer';
      }
      return 'Lainnya';
    }

    // Kamus Pengeluaran
    // 1. Makanan & Minuman
    if (_matches(teks, const [
      'kopi', 'coffee', 'cafe', 'kafe', 'latte', 'espresso', 'cappuccino',
      'starbucks', 'kenangan', 'janji jiwa', 'fore', 'mixue', 'haus', 'chatime',
      'makan', 'minum', 'resto', 'restoran', 'warung', 'warkop', 'mie', 'bakmi',
      'bakso', 'ayam', 'sate', 'nasi', 'gorengan', 'martabak', 'pizza', 'burger',
      'roti', 'snack', 'jajan', 'teh', 'boba', 'jus', 'juice', 'gofood', 'grabfood',
      'shopeefood', 'kantin', 'sarapan', 'lunch', 'dinner', 'mcd', 'kfc', 'hokben',
      'soto', 'rendang', 'seblak', 'pecel', 'angkringan', 'bebek', 'steak', 'pasta',
      'cemilan', 'es krim', 'ice cream', 'siomay', 'batagor', 'pempek', 'rawon'
    ])) {
      return 'Makan & Minum';
    }

    // 2. Transportasi
    if (_matches(teks, const [
      'bensin', 'pertalite', 'pertamax', 'solar', 'spbu', 'shell', 'bp',
      'grab', 'gojek', 'goride', 'gocar', 'maxim', 'indrive', 'ojol', 'ojek',
      'toll', 'tol', 'parkir', 'kereta', 'krl', 'mrt', 'lrt', 'busway', 'tj',
      'transjakarta', 'tiket pesawat', 'flight', 'taxi', 'taksi', 'angkot', 'damri',
      'service motor', 'service mobil', 'servis', 'bengkel', 'oli', 'tambal ban',
      'cuci motor', 'cuci mobil'
    ])) {
      return 'Transportasi';
    }

    // 3. Tagihan & Utilitas
    if (_matches(teks, const [
      'listrik', 'pln', 'token listrik', 'air', 'pdam', 'wifi', 'indihome', 'biznet',
      'firstmedia', 'myrepublic', 'pulsa', 'paket data', 'kuota', 'telkomsel', 'indosat',
      'xl', 'tri', 'smartfren', 'byu', 'bpjs', 'asuransi', 'iuran', 'netflix', 'spotify',
      'youtube premium', 'icloud', 'google one', 'sewa', 'kontrak', 'kost', 'kos'
    ])) {
      return 'Tagihan';
    }

    // 4. Belanja & Kebutuhan
    if (_matches(teks, const [
      'shopee', 'tokopedia', 'tiktok shop', 'lazada', 'blibli', 'indomaret', 'alfamart',
      'alfamidi', 'superindo', 'hypermart', 'supermarket', 'baju', 'celana', 'sepatu',
      'tas', 'kaos', 'jaket', 'kemeja', 'skincare', 'makeup', 'sabun', 'shampo',
      'parfum', 'belanja', 'mall', 'fashion', 'outfit'
    ])) {
      return 'Belanja';
    }

    // 5. Hiburan & Liburan
    if (_matches(teks, const [
      'nonton', 'bioskop', 'cinema', 'xxi', 'cgv', 'cinepolis', 'game', 'steam',
      'playstation', 'topup game', 'diamond', 'mlbb', 'genshin', 'karaoke',
      'liburan', 'hotel', 'staycation', 'tiket wisata', 'konser', 'rekreasi'
    ])) {
      return 'Hiburan';
    }

    // 6. Kesehatan & Medis
    if (_matches(teks, const [
      'obat', 'apotek', 'dokter', 'rumah sakit', 'rs', 'klinik', 'vitamin', 'suplemen',
      'tes darah', 'lab', 'periksa', 'konsul', 'halodoc', 'alodokter', 'kacamata', 'optik'
    ])) {
      return 'Kesehatan';
    }

    // 7. Pendidikan
    if (_matches(teks, const [
      'spp', 'kursus', 'buku', 'kuliah', 'sekolah', 'les', 'seminar', 'workshop',
      'udemy', 'bootcamp', 'alat tulis', 'fotocopy', 'uang gedung'
    ])) {
      return 'Pendidikan';
    }

    // 8. Kerja
    if (_matches(teks, const [
      'kerja', 'office', 'kantor', 'meeting', 'reimburse', 'bisnis', 'domain', 'hosting'
    ])) {
      return 'Kerja';
    }

    // 9. Sosial & Keluarga
    if (_matches(teks, const [
      'sedekah', 'infaq', 'zakat', 'donasi', 'uang saku', 'orang tua', 'anak', 'keluarga',
      'kondangan', 'kado', 'hadiah'
    ])) {
      return 'Sosial';
    }

    return null;
  }

  static bool _matches(String teks, List<String> keywords) {
    for (final kw in keywords) {
      if (teks == kw) return true;
      if (teks.contains(kw)) return true;
    }
    return false;
  }

  /// Kata-kata di [teks] yang dipakai sebagai kunci pencarian.
  static List<String> _kataPenting(String teks) {
    final kata = teks.split(RegExp(r'\s+'));
    return kata
        .where((k) => k.length >= _minKata && !_stopWords.contains(k))
        .toList();
  }

  static bool _cocok(String a, String b, List<String> kataKunci) {
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    final kataB = b.split(RegExp(r'\s+')).toSet();
    for (final k in kataKunci) {
      if (kataB.contains(k)) return true;
    }
    return false;
  }

  static const Set<String> _stopWords = {
    'dan', 'atau', 'untuk', 'dari', 'ke', 'di', 'yang', 'ini', 'itu',
    'saya', 'kamu', 'dia', 'ada', 'tidak', 'juga', 'sudah', 'belum',
    'beli', 'belanja', 'bayar', 'tebus',
  };
}
