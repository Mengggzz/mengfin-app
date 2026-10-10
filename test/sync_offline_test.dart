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
      expect(hasil.pending, 1);
      expect(hasil.adaGagal, isTrue);
      expect(hasil.lastError, isNotNull);
      final sisa = await LocalDb.getQueue();
      expect(sisa.length, 1, reason: 'item gagal harus tetap di antrean');
    });

    test('item gagal menyimpan retry_count & pesan error asli', () async {
      await LocalDb.enqueue(
        method: 'PUT',
        path: '/akun/server_y',
        body: '{"saldo":5000}',
        localId: 'akun_uji_err',
        tableName: 'akun',
      );

      await SyncService.instance.syncToServer(
        kirim: (item) async => false,
      );

      final sisa = await LocalDb.getQueue();
      expect(sisa.length, 1);
      expect(sisa.first['retry_count'], 1);
      expect((sisa.first['last_error'] as String).isNotEmpty, isTrue);
      expect((sisa.first['last_attempt'] as String).isNotEmpty, isTrue);
    });

    test('urutan antrean: akun dikirim lebih dulu dari transaksi', () async {
      await LocalDb.enqueue(
        method: 'POST', path: '/transaksi', body: '{}',
        localId: 'tx_urut_1', tableName: 'transaksi',
      );
      await LocalDb.enqueue(
        method: 'POST', path: '/akun', body: '{}',
        localId: 'akun_urut_1', tableName: 'akun',
      );

      final urutan = <String>[];
      await SyncService.instance.syncToServer(
        kirim: (item) async {
          urutan.add(item['table_name'] as String);
          return true;
        },
      );

      expect(urutan, ['akun', 'transaksi'],
          reason: 'dompet harus dibuat di cloud sebelum transaksi merujuknya');
    });
  });

  group('resolusi id lokal → id server', () {
    test('getServerIdForAkun mengembalikan id server setelah replace', () async {
      await LocalDb.insertAkunLocal({
        'nama': 'Dompet Resolusi',
        'jenis': 'cash',
        'saldo': 0,
        'warna': '#2563EB',
        'ikon': 'cash',
      }, 'akun_resol_1');

      // Sebelum sync: belum ada id server.
      expect(await LocalDb.getServerIdForAkun('akun_resol_1'), isNull);

      await LocalDb.replaceAkunLocalToServer('akun_resol_1', '507f1f77bcf86cd799439011');
      expect(await LocalDb.getServerIdForAkun('akun_resol_1'), '507f1f77bcf86cd799439011');
    });

    test('replaceAkunLocalToServer memperbarui akun_id di antrean transaksi',
        () async {
      const serverId = '507f1f77bcf86cd799439012';
      const localAkunId = 'akun_resol_2';

      await LocalDb.insertAkunLocal({
        'nama': 'Dompet Untuk Transaksi',
        'jenis': 'cash',
        'saldo': 0,
        'warna': '#2563EB',
        'ikon': 'cash',
      }, localAkunId);

      await LocalDb.enqueue(
        method: 'POST',
        path: '/transaksi',
        body: '{"tanggal":"2026-10-20","jenis":"pengeluaran",'
            '"nominal":10000,"kategori":"Belanja","akun_id":"$localAkunId"}',
        localId: 'tx_resol_2',
        tableName: 'transaksi',
      );

      await LocalDb.replaceAkunLocalToServer(localAkunId, serverId);

      final queue = await LocalDb.getQueue();
      final txItem = queue.firstWhere((q) => q['table_name'] == 'transaksi');
      expect((txItem['body'] as String).contains(serverId), isTrue,
          reason: 'antrean transaksi tidak boleh lagi memakai id dompet lokal');
      expect((txItem['body'] as String).contains(localAkunId), isFalse);
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

  group('Task 4c: antrean gagal permanen (permanent_failed)', () {
    test('item permanent_failed diabaikan dari getQueue() dan getPendingCount()',
        () async {
      final d = await LocalDb.db;
      // Masukkan 1 antrean normal
      await LocalDb.enqueue(
        method: 'POST',
        path: '/transaksi',
        body: '{"nominal":10000}',
        localId: 'tx_normal_1',
        tableName: 'transaksi',
      );

      // Masukkan 1 antrean gagal permanen (misal 404/validasi setelah retry >= 5)
      final queueId = await d.insert('sync_queue', {
        'method': 'POST',
        'path': '/transaksi',
        'body': '{"nominal":20000}',
        'local_id': 'tx_perm_failed',
        'table_name': 'transaksi',
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 5,
        'status': 'permanent_failed',
        'last_error': '404 Not Found',
      });

      final activeQueue = await LocalDb.getQueue();
      expect(activeQueue.length, 1,
          reason: 'Antrean aktif hanya boleh berisi item normal, bukan permanent_failed');
      expect(activeQueue.first['local_id'], 'tx_normal_1');

      final pendingCount = await LocalDb.getPendingCount();
      expect(pendingCount, 1,
          reason: 'Pending count tidak boleh mengikutsertakan item permanent_failed');

      final permFailedCount = await LocalDb.getPermanentFailedCount();
      expect(permFailedCount, 1,
          reason: 'Permanent failed count harus mendeteksi item yang gagal permanen');
    });
  });
}
