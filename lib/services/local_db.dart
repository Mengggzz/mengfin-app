import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'mengfin.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE transaksi (
            id INTEGER PRIMARY KEY,
            local_id TEXT UNIQUE,
            tanggal TEXT,
            jenis TEXT,
            nominal REAL,
            kategori TEXT,
            deskripsi TEXT,
            metode_pembayaran TEXT,
            akun_id INTEGER,
            akun_nama TEXT,
            synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE anggaran (
            id INTEGER PRIMARY KEY,
            local_id TEXT UNIQUE,
            kategori TEXT,
            batas REAL,
            periode TEXT,
            terpakai REAL DEFAULT 0,
            persentase REAL DEFAULT 0,
            synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE goals (
            id INTEGER PRIMARY KEY,
            local_id TEXT UNIQUE,
            nama TEXT,
            target REAL,
            terkumpul REAL DEFAULT 0,
            deadline TEXT,
            prioritas TEXT DEFAULT 'sedang',
            nabung_per_bulan REAL DEFAULT 0,
            catatan TEXT DEFAULT '',
            synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            method TEXT,
            path TEXT,
            body TEXT,
            local_id TEXT,
            table_name TEXT,
            created_at TEXT
          )
        ''');
      },
    );
  }

  // ── Transaksi ──────────────────────────────────────────────────────────────
  static Future<List<Transaksi>> getTransaksi({String? jenis, int limit = 100}) async {
    final d = await db;
    String where = jenis != null && jenis != 'semua' ? 'WHERE jenis = ?' : '';
    List<Object?> args = jenis != null && jenis != 'semua' ? [jenis] : [];
    final rows = await d.rawQuery(
      'SELECT * FROM transaksi $where ORDER BY tanggal DESC, id DESC LIMIT $limit',
      args,
    );
    return rows.map((r) => Transaksi(
      id: r['id'] as int,
      tanggal: r['tanggal'] as String,
      jenis: r['jenis'] as String,
      nominal: r['nominal'] as double,
      kategori: r['kategori'] as String,
      deskripsi: (r['deskripsi'] as String?) ?? '',
      metodePembayaran: (r['metode_pembayaran'] as String?) ?? 'tunai',
      akunId: r['akun_id'] as int?,
      akunNama: r['akun_nama'] as String?,
      synced: (r['synced'] as int? ?? 1) == 1,
    )).toList();
  }

  static Future<void> upsertTransaksi(Transaksi tx, {bool synced = true}) async {
    final d = await db;
    await d.insert('transaksi', {
      'id': tx.id,
      'local_id': tx.localId,
      'tanggal': tx.tanggal,
      'jenis': tx.jenis,
      'nominal': tx.nominal,
      'kategori': tx.kategori,
      'deskripsi': tx.deskripsi,
      'metode_pembayaran': tx.metodePembayaran,
      'akun_id': tx.akunId,
      'akun_nama': tx.akunNama,
      'synced': synced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> insertTransaksiLocal(Map<String, dynamic> data, String localId) async {
    final d = await db;
    final id = DateTime.now().millisecondsSinceEpoch * -1; // negative = local only
    await d.insert('transaksi', {
      'id': id,
      'local_id': localId,
      'tanggal': data['tanggal'],
      'jenis': data['jenis'],
      'nominal': data['nominal'],
      'kategori': data['kategori'],
      'deskripsi': data['deskripsi'] ?? '',
      'metode_pembayaran': data['metode_pembayaran'] ?? 'tunai',
      'akun_id': data['akun_id'],
      'akun_nama': null,
      'synced': 0,
    });
  }

  static Future<void> deleteTransaksi(int id) async {
    final d = await db;
    await d.delete('transaksi', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> replaceTransaksiLocalToServer(String localId, int serverId) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE transaksi SET id = ?, synced = 1 WHERE local_id = ?',
      [serverId, localId],
    );
  }

  static Future<void> markTransaksiSynced(String localId) async {
    final d = await db;
    await d.rawUpdate('UPDATE transaksi SET synced = 1 WHERE local_id = ?', [localId]);
  }

  // ── Anggaran ───────────────────────────────────────────────────────────────
  static Future<List<Anggaran>> getAnggaran(String periode) async {
    final d = await db;
    final rows = await d.query('anggaran', where: 'periode = ?', whereArgs: [periode]);
    return rows.map((r) => Anggaran(
      id: r['id'] as int,
      kategori: r['kategori'] as String,
      batas: r['batas'] as double,
      periode: r['periode'] as String,
      terpakai: (r['terpakai'] as num? ?? 0).toDouble(),
      persentase: (r['persentase'] as num? ?? 0).toDouble(),
      synced: (r['synced'] as int? ?? 1) == 1,
    )).toList();
  }

  static Future<void> upsertAnggaran(Anggaran a, {bool synced = true}) async {
    final d = await db;
    await d.insert('anggaran', {
      'id': a.id,
      'local_id': a.localId,
      'kategori': a.kategori,
      'batas': a.batas,
      'periode': a.periode,
      'terpakai': a.terpakai,
      'persentase': a.persentase,
      'synced': synced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> insertAnggaranLocal(String localId, String kategori, double batas, String periode) async {
    final d = await db;
    final id = DateTime.now().millisecondsSinceEpoch * -1;
    await d.insert('anggaran', {
      'id': id,
      'local_id': localId,
      'kategori': kategori,
      'batas': batas,
      'periode': periode,
      'terpakai': 0,
      'persentase': 0,
      'synced': 0,
    });
  }

  static Future<void> deleteAnggaran(int id) async {
    final d = await db;
    await d.delete('anggaran', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateAnggaranBatas(int id, double batas) async {
    final d = await db;
    await d.rawUpdate('UPDATE anggaran SET batas = ?, synced = 0 WHERE id = ?', [batas, id]);
  }

  // ── Goals ──────────────────────────────────────────────────────────────────
  static Future<List<Goal>> getGoals() async {
    final d = await db;
    final rows = await d.query('goals', orderBy: 'id DESC');
    return rows.map((r) => Goal(
      id: r['id'] as int,
      nama: r['nama'] as String,
      target: (r['target'] as num).toDouble(),
      terkumpul: (r['terkumpul'] as num? ?? 0).toDouble(),
      deadline: r['deadline'] as String?,
      prioritas: r['prioritas'] as String? ?? 'sedang',
      nabungPerBulan: (r['nabung_per_bulan'] as num? ?? 0).toDouble(),
      catatan: r['catatan'] as String? ?? '',
      synced: (r['synced'] as int? ?? 1) == 1,
    )).toList();
  }

  static Future<void> upsertGoal(Goal g, {bool synced = true}) async {
    final d = await db;
    await d.insert('goals', {
      'id': g.id,
      'local_id': g.localId,
      'nama': g.nama,
      'target': g.target,
      'terkumpul': g.terkumpul,
      'deadline': g.deadline,
      'prioritas': g.prioritas,
      'nabung_per_bulan': g.nabungPerBulan,
      'catatan': g.catatan,
      'synced': synced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> insertGoalLocal(String localId, Map<String, dynamic> data) async {
    final d = await db;
    final id = DateTime.now().millisecondsSinceEpoch * -1;
    await d.insert('goals', {
      'id': id,
      'local_id': localId,
      'nama': data['nama'],
      'target': data['target'],
      'terkumpul': 0,
      'deadline': data['deadline'],
      'prioritas': data['prioritas'] ?? 'sedang',
      'nabung_per_bulan': data['nabung_per_bulan'] ?? 0,
      'catatan': data['catatan'] ?? '',
      'synced': 0,
    });
  }

  static Future<void> deleteGoal(int id) async {
    final d = await db;
    await d.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateGoalProgres(int id, double tambah) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE goals SET terkumpul = terkumpul + ?, synced = 0 WHERE id = ?',
      [tambah, id],
    );
  }

  // ── Sync Queue ─────────────────────────────────────────────────────────────
  static Future<void> enqueue({
    required String method,
    required String path,
    required String body,
    required String localId,
    required String tableName,
  }) async {
    final d = await db;
    await d.insert('sync_queue', {
      'method': method,
      'path': path,
      'body': body,
      'local_id': localId,
      'table_name': tableName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getQueue() async {
    final d = await db;
    return d.query('sync_queue', orderBy: 'created_at ASC');
  }

  static Future<void> removeFromQueue(int id) async {
    final d = await db;
    await d.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> getPendingCount() async {
    final d = await db;
    final result = await d.rawQuery('SELECT COUNT(*) as c FROM sync_queue');
    return (result.first['c'] as int? ?? 0);
  }

  // ── Dashboard kalkulasi lokal ──────────────────────────────────────────────
  static Future<Map<String, double>> getDashboardLocal(String bulan) async {
    final d = await db;
    final rows = await d.rawQuery(
      "SELECT jenis, SUM(nominal) as total FROM transaksi WHERE tanggal LIKE ? GROUP BY jenis",
      ['$bulan%'],
    );
    double pemasukan = 0, pengeluaran = 0;
    for (final r in rows) {
      if (r['jenis'] == 'pemasukan') pemasukan = (r['total'] as num).toDouble();
      if (r['jenis'] == 'pengeluaran') pengeluaran = (r['total'] as num).toDouble();
    }
    final saldoRows = await d.rawQuery(
      "SELECT SUM(CASE WHEN jenis='pemasukan' THEN nominal ELSE -nominal END) as saldo FROM transaksi"
    );
    final saldo = (saldoRows.first['saldo'] as num? ?? 0).toDouble();
    return {
      'saldo': saldo,
      'pemasukan': pemasukan,
      'pengeluaran': pengeluaran,
    };
  }

  // ── Hapus semua data lokal (untuk fresh pull) ─────────────────────────────
  static Future<void> clearAll() async {
    final d = await db;
    await d.delete('transaksi');
    await d.delete('anggaran');
    await d.delete('goals');
  }
}
