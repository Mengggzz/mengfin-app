import '../models/models.dart';
import 'app_prefs.dart';

/// Logika dompet mana yang dipakai di tampilan.
///
/// Layar pengaturan menyimpan dua hal: dompet utama (satu, buat input default)
/// dan dompet tampil (bisa banyak, buat laporan). Sebelumnya pilihan itu cuma
/// state layar — ditutup, hilang. Sumbernya AppPrefs, jadi di sini cuma
/// membaca dan memilih.
class DompetView {
  /// Saldo total yang ditampilkan di beranda.
  ///
  /// [saldoServer] dipakai kalau daftar akun kosong (offline / server gagal /
  /// belum pernah ambil akun) supaya beranda tidak putus total.
  static double saldoTampil({
    required List<Akun> akun,
    required String? dompetUtama,
    required List<String> dompetTampil,
    required double saldoServer,
  }) {
    if (akun.isEmpty) return saldoServer;

    final pilihan = dompetTampil.isNotEmpty ? dompetTampil : const <String>[];
    if (pilihan.isNotEmpty) {
      final dipilih = akun
          .where((a) => pilihan.contains(AppPrefs.idKeTeks(a.id)))
          .toList();
      if (dipilih.isNotEmpty) {
        return dipilih.fold<double>(0, (s, a) => s + a.saldo);
      }
      // Semua dompet tampil sudah hilang dari daftar akun (dihapus) —
      // jangan diam-diam pakai dompet lain; tampilkan saldo server saja.
      return saldoServer;
    }

    // dompet tampil kosong → pakai dompet utama jika ada yang cocok.
    if (dompetUtama != null && dompetUtama.isNotEmpty) {
      final utama = akun.where(
        (a) => AppPrefs.idKeTeks(a.id) == dompetUtama,
      );
      if (utama.isNotEmpty) {
        return utama.first.saldo;
      }
    }

    // Default ketika tidak ada filter spesifik ("Semua Dompet"):
    // jumlahkan seluruh saldo dompet yang ada.
    return akun.fold<double>(0, (s, a) => s + a.saldo);
  }

  /// Dompet yang dipakai sebagai default saat input transaksi baru.
  static Akun? dompetAwal(List<Akun> akun, String? dompetUtama) {
    if (akun.isEmpty) return null;
    if (dompetUtama == null || dompetUtama.isEmpty) return akun.first;
    return akun.firstWhere(
      (a) => AppPrefs.idKeTeks(a.id) == dompetUtama,
      orElse: () => akun.first,
    );
  }
}
