import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/constants/utils.dart';
import 'package:mengfin/services/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.overridePathForTest(
      '${Directory.systemTemp.path}/mengfin_bulan_hint_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  setUp(() async {
    final d = await LocalDb.db;
    await d.delete('transaksi');
  });

  tearDownAll(() async {
    await LocalDb.closeForTest();
  });

  group('LocalDb.getBulanTerakhirTransaksi', () {
    test('kosong jika belum ada transaksi', () async {
      final res = await LocalDb.getBulanTerakhirTransaksi('2026-10');
      expect(res, isNull);
    });

    test('mengembalikan bulan terakhir sebelum bulan berjalan', () async {
      final d = await LocalDb.db;
      await d.insert('transaksi', {
        'id': 'tx_aug',
        'tanggal': '2026-08-10',
        'jenis': 'pengeluaran',
        'nominal': 50000,
        'kategori': 'Makan',
        'deskripsi': 'Tes',
        'synced': 1,
      });
      await d.insert('transaksi', {
        'id': 'tx_sep',
        'tanggal': '2026-09-28',
        'jenis': 'pengeluaran',
        'nominal': 75000,
        'kategori': 'Makan',
        'deskripsi': 'Tes Sep',
        'synced': 1,
      });

      final res = await LocalDb.getBulanTerakhirTransaksi('2026-10');
      expect(res, equals('2026-09'));
    });

    test('tidak mengembalikan bulan berjalan atau sesudahnya', () async {
      final d = await LocalDb.db;
      await d.insert('transaksi', {
        'id': 'tx_oct',
        'tanggal': '2026-10-02',
        'jenis': 'pengeluaran',
        'nominal': 20000,
        'kategori': 'Makan',
        'deskripsi': 'Tes Okt',
        'synced': 1,
      });

      final res = await LocalDb.getBulanTerakhirTransaksi('2026-10');
      expect(res, isNull);
    });

    test('formatBulan menghasilkan nama bulan Indonesia yang sesuai', () {
      expect(formatBulan('2026-09'), equals('September 2026'));
      expect(formatBulan('2026-08'), equals('Agustus 2026'));
    });
  });
}
