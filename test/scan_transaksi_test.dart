import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/api_service.dart';
import 'package:mengfin/services/local_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regresi bug "transaksi hasil scan tidak muncul".
///
/// Alur yang diuji:
///   1. Scan struk → transaksi disimpan (dulunya hanya di server).
///   2. Server tidak bisa dihubungi → baris lokal tertinggal dengan synced = 0.
///   3. Daftar transaksi HARUS tetap menampilkan baris itu.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.overridePathForTest(
      '${Directory.systemTemp.path}/mengfin_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  tearDownAll(() async {
    await LocalDb.closeForTest();
  });

  test('baris lokal yang belum tersinkron tetap muncul di daftar', () async {
    // Simulasi hasil simpan saat offline: hanya baris lokal, synced = 0.
    await LocalDb.insertTransaksiLocal({
      'tanggal': '2026-09-25',
      'jenis': 'pengeluaran',
      'nominal': 32190,
      'kategori': 'Belanja',
      'deskripsi': 'INDOMARET',
      'metode_pembayaran': 'tunai',
    }, 'tx_uji_1');

    final pending = await LocalDb.getTransaksi(hanyaBelumSync: true);
    expect(pending.length, 1, reason: 'baris synced=0 harus terambil');
    expect(pending.first.deskripsi, 'INDOMARET');
    expect(pending.first.nominal, 32190);

    // Semua baris (tanpa filter) juga harus memuat baris lokal ini.
    final semua = await LocalDb.getTransaksi();
    expect(semua.any((t) => t.deskripsi == 'INDOMARET'), isTrue,
        reason: 'daftar transaksi tidak boleh menyembunyikan baris lokal');
  });

  test('setelah tersinkron, baris tidak lagi dihitung pending', () async {
    await LocalDb.insertTransaksiLocal({
      'tanggal': '2026-09-25',
      'jenis': 'pengeluaran',
      'nominal': 5000,
      'kategori': 'Makanan',
      'deskripsi': 'Warteg',
      'metode_pembayaran': 'tunai',
    }, 'tx_uji_2');

    await LocalDb.replaceTransaksiLocalToServer('tx_uji_2', 'server_id_2');

    final pending = await LocalDb.getTransaksi(hanyaBelumSync: true);
    expect(pending.any((t) => t.deskripsi == 'Warteg'), isFalse,
        reason: 'baris yang sudah terkirim tidak boleh muncul sebagai pending');
  });

  test('getTransaksi menggabungkan baris lokal dengan daftar server', () async {
    // Baris lokal baru (simulasi scan struk yang uploadnya gagal).
    await LocalDb.insertTransaksiLocal({
      'tanggal': '2026-09-25',
      'jenis': 'pengeluaran',
      'nominal': 12345,
      'kategori': 'Belanja',
      'deskripsi': 'STRUK_GAGAL_UPLOAD',
      'metode_pembayaran': 'tunai',
    }, 'tx_uji_3');

    // Tanpa jaringan: _online false → harus jatuh ke data lokal, bukan
    // daftar kosong (inilah yang bikin transaksi seolah hilang).
    final hasil = await ApiService.getTransaksi(limit: 50);
    expect(hasil.any((t) => t.deskripsi == 'STRUK_GAGAL_UPLOAD'), isTrue,
        reason: 'transaksi hasil scan harus terlihat walau upload gagal');
  });
}
