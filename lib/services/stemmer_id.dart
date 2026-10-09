/// Stemmer Bahasa Indonesia ringan untuk kategorisasi transaksi.
/// Bukan Sastrawi penuh — hanya menangani afiks umum agar keyword cocok.
/// Selalu kembalikan varian [kataAsli, ...hasilStem]; pencocokan mencoba semua.
class StemmerId {
  StemmerId._();

  /// Kembalikan kata asli + semua varian stem yang valid (panjang >= 3).
  static List<String> varian(String kata) {
    kata = kata.toLowerCase().trim();
    if (kata.length < 4) return [kata];
    final hasil = <String>{kata};
    for (final v in _lepasAkhiran(kata)) {
      hasil.add(v);
      for (final v2 in _lepasAwalan(v)) {
        hasil.add(v2);
      }
    }
    for (final v in _lepasAwalan(kata)) {
      hasil.add(v);
    }
    return hasil.where((s) => s.length >= 3).toList();
  }

  static List<String> _lepasAkhiran(String k) {
    const akhiran = ['nya', 'kan', 'lah', 'kah', 'pun', 'ku', 'mu', 'an', 'i'];
    for (final a in akhiran) {
      if (k.endsWith(a) && k.length - a.length >= 3) {
        return [k.substring(0, k.length - a.length)];
      }
    }
    return [];
  }

  static List<String> _lepasAwalan(String k) {
    // kembali ke huruf awal yang luluh: menyapu->sapu, menulis->tulis, memasak->masak
    const awalan = {
      'meny': 's',
      'menge': '',
      'meng': '',
      'men': 't',
      'mem': 'p',
      'me': '',
      'peny': 's',
      'peng': '',
      'pen': 't',
      'pem': 'p',
      'pe': '',
      'ber': '',
      'ter': '',
      'per': '',
      'di': '',
      'ke': '',
      'se': '',
    };
    for (final e in awalan.entries) {
      if (k.startsWith(e.key) && k.length - e.key.length >= 3) {
        final sisa = k.substring(e.key.length);
        final kandidat = <String>[sisa];
        if (e.value.isNotEmpty) kandidat.add(e.value + sisa);
        // khusus men-/mem-/pen-/pem- + vokal: coba tanpa restorasi juga
        return kandidat;
      }
    }
    return [];
  }
}
