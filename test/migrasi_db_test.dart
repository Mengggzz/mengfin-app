import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mengfin/services/local_db.dart';

/// Tes migrasi basis data v1 → v3.
///
/// DB v1 (era backend SQLite lama) memakai `id INTEGER`. DB sekarang v3:
/// id TEXT (MongoDB ObjectId) + tabel `akun` baru. Pengguna lama yang sudah
/// punya DB v1 harus tetap tidak kehilangan data: transaksi, anggaran, goals,
/// dan sync_queue harus ikut pindah, dan tabel akun harus tercipta.
///
/// Sebelumnya hanya `onCreate` yang teruji (DB baru langsung v3); jalur
/// `onUpgrade` untuk pengguna lama tidak pernah diuji.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// Bangun sebuah file DB v1 sebagaimana adanya versi lama aplikasi:
  /// tiga tabel dengan `id INTEGER`, tanpa tabel `akun`.
  Future<String> buatDbV1() async {
    final path = p.join(
      Directory.systemTemp.path,
      'mengfin_v1_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''CREATE TABLE IF NOT EXISTS transaksi (
          id INTEGER PRIMARY KEY,
          local_id TEXT,
          tanggal TEXT,
          jenis TEXT,
          nominal REAL,
          kategori TEXT,
          deskripsi TEXT,
          metode_pembayaran TEXT,
          akun_id INTEGER,
          akun_nama TEXT,
          synced INTEGER DEFAULT 1
        )''');
        await db.execute('''CREATE TABLE IF NOT EXISTS anggaran (
          id INTEGER PRIMARY KEY,
          local_id TEXT,
          kategori TEXT,
          batas REAL,
          periode TEXT,
          terpakai REAL DEFAULT 0,
          persentase REAL DEFAULT 0,
          synced INTEGER DEFAULT 1
        )''');
        await db.execute('''CREATE TABLE IF NOT EXISTS goals (
          id INTEGER PRIMARY KEY,
          local_id TEXT,
          nama TEXT,
          target REAL,
          terkumpul REAL DEFAULT 0,
          deadline TEXT,
          prioritas TEXT DEFAULT 'sedang',
          nabung_per_bulan REAL DEFAULT 0,
          catatan TEXT DEFAULT '',
          synced INTEGER DEFAULT 1
        )''');
        await db.execute('''CREATE TABLE IF NOT EXISTS sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          method TEXT,
          path TEXT,
          body TEXT,
          local_id TEXT,
          table_name TEXT,
          created_at TEXT
        )''');

        // Data pengguna lama di tiap tabel.
        await db.insert('transaksi', {
          'id': 101, 'local_id': 'tx_lama_1',
          'tanggal': '2026-09-01', 'jenis': 'pemasukan',
          'nominal': 250000.0, 'kategori': 'Gaji',
          'deskripsi': 'gaji sept', 'metode_pembayaran': 'transfer',
          'akun_id': 7, 'akun_nama': 'BCA', 'synced': 1,
        });
        await db.insert('transaksi', {
          'id': 102, 'local_id': 'tx_lama_2',
          'tanggal': '2026-09-03', 'jenis': 'pengeluaran',
          'nominal': 45000.0, 'kategori': 'Makan',
          'deskripsi': 'ayam', 'metode_pembayaran': 'tunai',
          'akun_id': null, 'akun_nama': null, 'synced': 0,
        });
        await db.insert('anggaran', {
          'id': 201, 'local_id': 'ag_lama_1',
          'kategori': 'Makan', 'batas': 500000.0,
          'periode': '2026-09', 'terpakai': 45000.0,
          'persentase': 9.0, 'synced': 1,
        });
        await db.insert('goals', {
          'id': 301, 'local_id': 'gl_lama_1',
          'nama': 'Motor', 'target': 15000000.0,
          'terkumpul': 2000000.0, 'deadline': '2026-12-31',
          'prioritas': 'tinggi', 'nabung_per_bulan': 500000.0,
          'catatan': ' DP ', 'synced': 0,
        });
        await db.insert('sync_queue', {
          'method': 'POST', 'path': '/transaksi',
          'body': '{}', 'local_id': 'tx_lama_2',
          'table_name': 'transaksi', 'created_at': '2026-09-03T10:00:00',
        });
      },
    );
    await db.close();
    return path;
  }

  test('DB v1 → v3: data pengguna lama tidak hilang', () async {
    final path = await buatDbV1();
    LocalDb.overridePathForTest(path);

    // Membuka DB lewat LocalDb memicu onUpgrade dari v1 ke v3.
    final txs = await LocalDb.getTransaksi();
    expect(txs.length, 2, reason: 'transaksi lama harus ikut pindah');
    expect(txs.any((t) => t.deskripsi == 'gaji sept'), isTrue);
    expect(txs.any((t) => t.deskripsi == 'ayam'), isTrue);

    final budgets = await LocalDb.getAnggaran('2026-09');
    expect(budgets.length, 1);
    expect(budgets.first.kategori, 'Makan');
    expect(budgets.first.batas, 500000.0);

    final queue = await LocalDb.getQueue();
    expect(queue.length, 1, reason: 'antrean sync lama harus utuh');
    expect(queue.first['table_name'], 'transaksi');

    // Tabel akun harus tercipta (tidak ada di v1).
    final akun = await LocalDb.getAkunList();
    expect(akun, isEmpty, reason: 'tabel akun baru & kosong');

    await LocalDb.closeForTest();
    File(path).deleteSync();
  });

  test('DB v1 → v3: id INTEGER dikonversi jadi TEXT', () async {
    final path = await buatDbV1();
    LocalDb.overridePathForTest(path);
    final d = await LocalDb.db;

    // Kolom id sekarang TEXT (SQLite LONGTEXT); nilai 101 menjadi '101'.
    final row = await d.rawQuery('SELECT id, akun_id FROM transaksi WHERE local_id = ?', ['tx_lama_1']);
    expect(row.first['id'].toString(), '101');
    expect(row.first['akun_id'].toString(), '7');

    await LocalDb.closeForTest();
    File(path).deleteSync();
  });
}
