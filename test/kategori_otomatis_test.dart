import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mengfin/models/models.dart';
import 'package:mengfin/screens/settings_screen.dart';
import 'package:mengfin/services/app_prefs.dart';
import 'package:mengfin/services/kategori_otomatis.dart';

/// Tombol "otomatis kategorikan" di layar input dulu cuma ikon hiasan: tidak
/// ada kode yang mengambil kategori transaksi terakhir. Tes ini menuntut
/// ada logika murni yang bisa diuji dan benar-benar dipakai layar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Transaksi tx(String id, String tanggal, String kategori, String deskripsi,
          double nominal) =>
      Transaksi(
        id: id,
        tanggal: tanggal,
        jenis: 'pengeluaran',
        nominal: nominal,
        kategori: kategori,
        deskripsi: deskripsi,
        metodePembayaran: 'tunai',
      );

  group('KategoriOtomatis', () {
    test('pakai kategori transaksi terakhir yang sama persis deskripsinya',
        () {
      final riwayat = [
        tx('1', '2026-09-20', 'Makan & Minum', 'kopi', 18000),
        tx('2', '2026-09-25', 'Transportasi', 'grab', 25000),
      ];
      final hasil = KategoriOtomatis.tebak(deskripsi: 'kopi', riwayat: riwayat);
      expect(hasil, 'Makan & Minum');
    });

    test('cocok sebagian: "kopi susu" → transaksi "kopi"', () {
      final riwayat = [
        tx('1', '2026-09-20', 'Makan & Minum', 'kopi', 18000),
      ];
      final hasil =
          KategoriOtomatis.tebak(deskripsi: 'kopi susu', riwayat: riwayat);
      expect(hasil, 'Makan & Minum');
    });

    test('cocok sebagian sekali jalan: "grab ke kantor" → "grab"', () {
      final riwayat = [
        tx('1', '2026-09-20', 'Transportasi', 'grab', 25000),
      ];
      final hasil =
          KategoriOtomatis.tebak(deskripsi: 'grab ke kantor', riwayat: riwayat);
      expect(hasil, 'Transportasi');
    });

    test('deskripsi kosong tidak memakai tebakan sembarang', () {
      final riwayat = [
        tx('1', '2026-09-20', 'Makan & Minum', 'kopi', 18000),
      ];
      expect(KategoriOtomatis.tebak(deskripsi: '', riwayat: riwayat), isNull);
    });

    test('tidak ada riwayat sama sekali → null (bukan kategori default)', () {
      expect(KategoriOtomatis.tebak(deskripsi: 'kopi', riwayat: const []),
          isNull);
    });

    test('tak ada yang cocok → null, bukan kategori pertama', () {
      final riwayat = [
        tx('1', '2026-09-20', 'Makan & Minum', 'kopi', 18000),
      ];
      expect(
          KategoriOtomatis.tebak(deskripsi: 'bensin', riwayat: riwayat),
          isNull,
          reason: 'jangan nebak kategori asal hanya karena ada riwayat');
    });

    test('kata kunci tidak boleh cocok sebagian terlalu pendek', () {
      final riwayat = [
        tx('1', '2026-09-20', 'Makan & Minum', 'kopi', 18000),
      ];
      // "op" adalah substring "kopi" tapi bukan kata yang berarti.
      expect(KategoriOtomatis.tebak(deskripsi: 'op', riwayat: riwayat), isNull);
    });

    test('riwayat kosong/null aman', () {
      expect(KategoriOtomatis.tebak(deskripsi: 'kopi', riwayat: null), isNull);
    });

    test('riwayat di luar 30 hari tidak dipakai (kategori bisa berubah)', () {
      final riwayat = [
        tx('1', '2026-01-01', 'Makan & Minum', 'kopi', 18000),
      ];
      expect(KategoriOtomatis.tebak(deskripsi: 'kopi', riwayat: riwayat),
          isNull);
    });

    test('kamus kata kunci otomatis: kopi -> Makan & Minum, bensin -> Transportasi', () {
      expect(
        KategoriOtomatis.tebak(deskripsi: 'kopi', gunakanKamus: true),
        'Makan & Minum',
      );
      expect(
        KategoriOtomatis.tebak(deskripsi: 'beli bensin pertalite', gunakanKamus: true),
        'Transportasi',
      );
      expect(
        KategoriOtomatis.tebak(deskripsi: 'bayar tagihan listrik pln', gunakanKamus: true),
        'Tagihan',
      );
      expect(
        KategoriOtomatis.tebak(deskripsi: 'belanja di shopee', gunakanKamus: true),
        'Belanja',
      );
      expect(
        KategoriOtomatis.tebak(deskripsi: 'gaji bulanan', gunakanKamus: true, isExpense: false),
        'Gaji',
      );
    });
  });

  group('layar pengaturan auto-notif', () {
    testWidgets('banner tidak menyebut Premium (tidak ada sistem premium)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AppPrefs.instance.reset();
      await AppPrefs.instance.init();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          page: SettingsPage.autoNotif,
          muatAkun: () async => const [],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Premium'), findsNothing,
          reason: 'tidak ada sistem premium, jangan janji yang tidak ada');
    });
  });
}

