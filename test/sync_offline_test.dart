import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/models/models.dart';
import 'package:mengfin/services/local_db.dart';
import 'package:mengfin/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Regresi sinkronisasi online/offline.
///
/// Sebelumnya:
///  - `sync_queue` dengan table_name 'akun' tidak punya cabang di
///    SyncService.syncToServer → item dihapus dari antrean padahal tidak
///    pernah dikirim ke server (dompet hilang saat offline).
///  - Daftar akun (dompet) tidak pernah disimpan lokal → saat offline,
///    pemilih dompet di input transaksi kosong.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDb.overridePathForTest(
      '${Directory.systemTemp.path}/mengfin_sync_test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
  });

  setUp(() async {
    // Tiap test harus mandiri: bersihkan semua baris sebelumnya.
    final d = await LocalDb.db;
    await d.delete('akun');
    await d.delete('transaksi');
    await d.delete('sync_queue');
  });

  tearDownAll(() async {
    await LocalDb.closeForTest();
  });

  group('dompet (akun) offline', () {
    test('akun yang dibuat offline tersimpan lokal dan muncul di daftar',
        () async {
      await LocalDb.insertAkunLocal({
        'nama': 'Dompet GoPay',
        'jenis': 'gopay',
        'saldo': 100000,
        'warna': '#0ABDE3',
        'ikon': 'gopay',
      }, 'akun_uji_1');

      final list = await LocalDb.getAkunList();
      expect(list.length, 1);
      expect(list.first.nama, 'Dompet GoPay');
      expect(list.first.saldo, 100000);
    });

    test('akun dari server menimpa id lokal setelah sync', () async {
      await LocalDb.insertAkunLocal({
        'nama': 'Dompet Baru',
        'jenis': 'cash',
        'saldo': 0,
        'warna': '#2563EB',
        'ikon': 'cash',
      }, 'akun_uji_2');

      await LocalDb.replaceAkunLocalToServer('akun_uji_2', 'server_akun_2');

      final list = await LocalDb.getAkunList();
      expect(list.length, 1);
      expect(list.first.id, 'server_akun_2');
    });

    test('saldo akun lokal bisa diubah saat offline', () async {
      await LocalDb.insertAkunLocal({
        'nama': 'Dompet Cash',
        'jenis': 'cash',
        'saldo': 50000,
        'warna': '#2563EB',
        'ikon': 'cash',
      }, 'akun_uji_3');

      await LocalDb.updateAkunSaldoLocal('akun_uji_3', 75000);

      final list = await LocalDb.getAkunList();
      expect(list.first.saldo, 75000);
    });

    test('daftar dompet gabungan: lokal (belum sync) + server', () async {
      // Dompet yang dibuat saat offline (masih id lokal).
      await LocalDb.insertAkunLocal({
        'nama': 'Dompet Offline',
        'jenis': 'cash',
        'saldo': 10000,
        'warna': '#2563EB',
        'ikon': 'cash',
      }, 'akun_offline_1');

      // Dompet dari server (sudah sync).
      await LocalDb.upsertAkunList([
        Akun(
          id: 'server_dompet_1',
          nama: 'Dompet Server',
          jenis: 'bank',
          saldo: 500000,
          warna: '#0ABDE3',
          ikon: 'bank',
        ),
      ]);

      final list = await LocalDb.getAkunList();
      expect(list.length, 2);
      expect(list.map((a) => a.nama).toSet(),
          containsAll(['Dompet Offline', 'Dompet Server']));
    });
  });

  group('SyncService.syncToServer', () {
    test('item antrean akun benar-benar dikirim ke server', () async {
      await LocalDb.enqueue(
        method: 'POST',
        path: '/akun',
        body: '{"nama":"Dompet GoPay","jenis":"gopay","saldo":100000}',
        localId: 'akun_uji_sync',
        tableName: 'akun',
      );

      final dipanggil = <String>[];
      final hasil = await SyncService.instance.syncToServer(
        kirim: (item) async {
          dipanggil.add('${item['method']} ${item['table_name']}');
          return true;
        },
      );

      expect(dipanggil, ['POST akun'], reason: 'item akun harus dikirim');
      expect(hasil.terkirim, 1);
      expect(hasil.gagal, 0);

      final sisa = await LocalDb.getQueue();
      expect(sisa.isEmpty, true, reason: 'item sukses harus keluar antrean');
    });

    test('item yang gagal tetap di antrean untuk dicoba lagi', () async {
      await LocalDb.enqueue(
        method: 'PUT',
        path: '/akun/server_x',
        body: '{"saldo":20000}',
        localId: 'akun_uji_gagal',
        tableName: 'akun',
      );

      final hasil = await SyncService.instance.syncToServer(
        kirim: (item) async => false,
      );

      expect(hasil.gagal, 1);
      final sisa = await LocalDb.getQueue();
      expect(sisa.length, 1, reason: 'item gagal harus tetap di antrean');
    });
  });

  group('regresi id String pada transaksi', () {
    test('delete & update dengan id String (server ObjectId) berhasil',
        () async {
      await LocalDb.insertTransaksiLocal({
        'tanggal': '2026-10-20',
        'jenis': 'pengeluaran',
        'nominal': 50000,
        'kategori': 'Belanja',
        'deskripsi': 'uji string id',
      }, 'tx_uji_str');

      await LocalDb.updateTransaksiLocal('tx_uji_str', {'nominal': 35000});
      var pending = await LocalDb.getTransaksi(hanyaBelumSync: true);
      expect(pending.length, 1);
      expect(pending.first.nominal, 35000);

      await LocalDb.deleteTransaksi('tx_uji_str');
      pending = await LocalDb.getTransaksi(hanyaBelumSync: true);
      expect(pending.isEmpty, true);
    });
  });
}
