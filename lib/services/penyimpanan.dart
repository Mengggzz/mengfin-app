/// Hasil dari operasi yang disimpan lewat [Penyimpanan.simpan].
class HasilSimpan {
  const HasilSimpan({required this.gagal, this.pesan});
  final bool gagal;
  final String? pesan;
}

/// Helper agar operasi simpan (anggaran/goals/akun) tidak diam saja jika gagal.
///
/// Sebelumnya layar anggaran/goals/kazz: await ApiService.updateAnggaran(...) lalu
/// Navigator.pop(context); _load(). Server menolak → exception langsung, modal tetap
/// terbuka, pengguna tidak tahu. Ini mengubah pola jadi satu baris:
/// final hasil = await Penyimpanan.simpan(() async { ... });
/// if (hasil.gagal) showError(hasil.pesan) else close().
class Penyimpanan {
  Penyimpanan._();

  /// Jalankan [opsi] dalam try/catch dan kembalikan status + pesan yang ramah.
  static Future<HasilSimpan> simpan(Future Function() opsi) async {
    try {
      await opsi();
      return const HasilSimpan(gagal: false);
    } catch (e) {
      final errStr = e.toString();
      // Pahami pengecualian umum yang biasanya terjadi di backend/API.
      if (errStr.contains('unauthorized')) {
        // Token pengguna habis — jangan jelaskan teknis.
        return const HasilSimpan(
          gagal: true,
          pesan: 'Koneksi tidak sah. Silakan login ulang.',
        );
      }
      if (errStr.contains('timeout') || errStr.contains('timed out')) {
        return const HasilSimpan(
          gagal: true,
          pesan: 'Server tidak merespon. Cek koneksi internet.',
        );
      }
      if (errStr.contains('500') || errStr.contains('internal server error')) {
        return const HasilSimpan(
          gagal: true,
          pesan: 'Server sedang bermasalah. Coba lagi nanti.',
        );
      }
      if (errStr.contains('offline') ||
          errStr.contains('Network request failed')) {
        return const HasilSimpan(
          gagal: true,
          pesan:
              'Tidak ada koneksi internet. Data akan disinkronkan otomatis saat online.',
        );
      }
      // Pesan default, tapi singkirkan "Exception:" prefix supaya lebih bersih.
      final message = errStr.replaceFirst('Exception: ', '');
      return HasilSimpan(
        gagal: true,
        pesan: message.isEmpty
            ? 'Gagal menyimpan data.'
            : 'Gagal menyimpan: $message',
      );
    }
  }
}
