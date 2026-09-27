import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/penyimpanan.dart';

/// Sebelumnya anggaran/goals: `await ApiService.updateAnggaran(...)` lalu
/// langsung `Navigator.pop(context)` tanpa try/catch. Server gagal → pengecualian
/// tidak ditangkap, modal tetap terbuka, pengguna tidak tahu simpanannya
/// hilang. Bukan hanya tidak ada pesan: kalau terjadi setelah app idle,
/// kegagalan itu kelihatan seperti "berhasil tapi datanya tidak ada".
void main() {
  group('Penyimpanan.hasilSimpan', () {
    test('sukses → hasil sukses, bukan error', () async {
      final hasil = await Penyimpanan.simpan(() async {});
      expect(hasil.gagal, isFalse);
      expect(hasil.pesan, isNull);
    });

    test('gagal lempar pengecualian → hasil gagal dengan pesan', () async {
      final hasil = await Penyimpanan.simpan(
        () async => throw Exception('koneksi terputus'),
      );
      expect(hasil.gagal, isTrue);
      expect(hasil.pesan, contains('koneksi terputus'));
    });

    test('gagal dengan pengecualian tanpa pesan → teks cadangan', () async {
      final hasil = await Penyimpanan.simpan(
        () async => throw FormatException(),
      );
      expect(hasil.gagal, isTrue);
      expect(hasil.pesan, isNotEmpty);
    });

    test('pesan pengecualian unauthorized dialihkan ke teks yang berguna',
        () async {
      final hasil = await Penyimpanan.simpan(
        () async => throw Exception('unauthorized'),
      );
      expect(hasil.gagal, isTrue);
      // 'unauthorized' tidak menjelaskan apa-apa untuk pengguna.
      expect(hasil.pesan, isNot(contains('unauthorized')));
    });

    test('null vs false: hasil sukses tidak boleh memuat pesan', () async {
      final hasil = await Penyimpanan.simpan(() async => 42);
      expect(hasil.gagal, isFalse);
      expect(hasil.pesan, isNull);
    });
  });
}
