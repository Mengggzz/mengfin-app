import '../models/models.dart';

/// Tebak kategori transaksi dari riwayat pengguna.
///
/// Layar input punya ikon `auto_fix_high` + teks "Otomatis kategorikan dari
/// transaksi terakhir" yang dulu tidak ada kode pendukungnya. Ini logika
/// murninya, terpisah dari layar supaya bisa diuji tanpa server.
///
/// Aturan: cari transaksi terakhir (dalam 30 hari) yang deskripsinya cocok
/// kata-per-kata dengan deskripsi baru. Kalau tidak ada, kembalikan null —
/// jangan nebak kategori asal, karena tebakan salah lebih menyusahkan
/// pengguna daripada memilih manual.
class KategoriOtomatis {
  KategoriOtomatis._();

  /// Batas: riwayat lebih lama dari ini tidak dipakai, karena kebiasaan
  /// pengguna bisa berubah (dulu "grab" masuk Transportasi, sekarang
  /// mungkin sudah diganti kategorinya sendiri).
  static const int _maksHari = 30;

  /// Panjang minimum kata kunci supaya kecocokan sebagian tidak menyeret
  /// kata yang kebetulan mengandung substring pendek (mis. "op" di "kopi").
  static const int _minKata = 3;

  /// Tebak kategori untuk [deskripsi].
  ///
  /// [riwayat] harus diurutkan dari yang paling baru (pemanggil memakai
  /// `ApiService.getTransaksi` yang sudah terurut tanggal desc). Mengembalikan
  /// null kalau tidak ada tebakan yang layak.
  static String? tebak({required String deskripsi, List<Transaksi>? riwayat}) {
    final teks = deskripsi.trim().toLowerCase();
    if (teks.isEmpty || riwayat == null || riwayat.isEmpty) return null;

    final kataKunci = _kataPenting(teks);
    if (kataKunci.isEmpty) return null;

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
    return null;
  }

  /// Kata-kata di [teks] yang dipakai sebagai kunci pencarian.
  static List<String> _kataPenting(String teks) {
    final kata = teks.split(RegExp(r'\s+'));
    return kata
        .where((k) => k.length >= _minKata && !_stopWords.contains(k))
        .toList();
  }

  /// true kalau kedua teks berbagi setidaknya satu kata kunci yang utuh,
  /// ATAU salah satu deskripsi adalah substring dari yang lain (mis. "kopi"
  /// vs "kopi susu"). Kecocokan substring hanya untuk deskripsi pendek
  /// yang tidak punya kata lain.
  static bool _cocok(String a, String b, List<String> kataKunci) {
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    final kataB = b.split(RegExp(r'\s+')).toSet();
    for (final k in kataKunci) {
      if (kataB.contains(k)) return true;
    }
    return false;
  }

  /// Kata umum yang tidak boleh jadi kunci (terlalu umum → banyak false
  /// positive).
  static const Set<String> _stopWords = {
    'dan', 'atau', 'untuk', 'dari', 'ke', 'di', 'yang', 'ini', 'itu',
    'saya', 'kamu', 'dia', 'ada', 'tidak', 'juga', 'sudah', 'belum',
    'beli', 'belanja', 'bayar', 'tebus',
  };
}
