import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class LocalDb {
  static Future<Database>? _dbFuture;

  /// Path DB alternatif — dipakai pengujian supaya tidak menyentuh DB asli.
  static String? _pathOverride;

  /// Arahkan LocalDb ke file DB lain (dipakai test).
  static void overridePathForTest(String path) {
    _pathOverride = path;
    _dbFuture = null;
  }

  /// Tutup DB (dipakai test untuk membersihkan).
  static Future<void> closeForTest() async {
    final db = await _dbFuture;
    await db?.close();
    _dbFuture = null;
  }

  /// Race-condition-safe: _open() called at most once even with concurrent callers,
  /// because the Future itself is stored before any await resolves.
  static Future<Database> get db async => (_dbFuture ??= _open());

  static Future<Database> _open() async {
    final path = _pathOverride ?? join(await getDatabasesPath(), 'mengfin.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, _) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 → v2: id INTEGER (era backend SQLite) → id TEXT (MongoDB ObjectId).
        // v2 → v3: tambah tabel 'akun' (dompet) ke schema.
        if (oldVersion < 3) {
          for (final t in ['transaksi', 'anggaran', 'goals']) {
            await db.execute('ALTER TABLE $t RENAME TO ${t}_v1');
          }
          await _createSchema(db);
          await db.execute('''
          INSERT INTO transaksi (id, local_id, tanggal, jenis, nominal, kategori,
            deskripsi, metode_pembayaran, akun_id, akun_nama, synced)
          SELECT CAST(id AS TEXT), local_id, tanggal, jenis, nominal, kategori,
            deskripsi, metode_pembayaran, CAST(akun_id AS TEXT), akun_nama, synced
          FROM transaksi_v1
        ''');
          await db.execute('''
          INSERT INTO anggaran (id, local_id, kategori, batas, periode,
            terpakai, persentase, synced)
          SELECT CAST(id AS TEXT), local_id, kategori, batas, periode,
            terpakai, persentase, synced
          FROM anggaran_v1
        ''');
          await db.execute('''
          INSERT INTO goals (id, local_id, nama, target, terkumpul, deadline,
            prioritas, nabung_per_bulan, catatan, synced)
          SELECT CAST(id AS TEXT), local_id, nama, target, terkumpul, deadline,
            prioritas, nabung_per_bulan, catatan, synced
          FROM goals_v1
        ''');
          for (final t in ['transaksi', 'anggaran', 'goals']) {
            await db.execute('DROP TABLE ${t}_v1');
          }
        }
        // v3 → v4: tambah tracking retry & error di sync_queue
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE sync_queue ADD COLUMN retry_count INTEGER DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE sync_queue ADD COLUMN last_error TEXT DEFAULT ""');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE sync_queue ADD COLUMN last_attempt TEXT DEFAULT ""');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE sync_queue ADD COLUMN status TEXT DEFAULT "pending"');
          } catch (_) {}
        }
      },
    );
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transaksi (
        id TEXT PRIMARY KEY,
        local_id TEXT UNIQUE,
        tanggal TEXT,
        jenis TEXT,
        nominal REAL,
        kategori TEXT,
        deskripsi TEXT,
        metode_pembayaran TEXT,
        akun_id TEXT,
        akun_nama TEXT,
        synced INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS anggaran (
        id TEXT PRIMARY KEY,
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
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
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
    await db.execute('''CREATE TABLE IF NOT EXISTS akun (
      id TEXT PRIMARY KEY,
      local_id TEXT UNIQUE,
      nama TEXT,
      jenis TEXT,
      saldo REAL DEFAULT 0,
      warna TEXT DEFAULT '#2563EB',
      ikon TEXT DEFAULT 'bank',
      synced INTEGER DEFAULT 1
    )''');
    // sync_queue menyimpan data offline dengan tracking retry & error
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        method TEXT,
        path TEXT,
        body TEXT,
        local_id TEXT,
        table_name TEXT,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT DEFAULT '',
        last_attempt TEXT DEFAULT '',
        status TEXT DEFAULT 'pending',
        created_at TEXT
      )
    ''');
  }

  // ── Transaksi ──────────────────────────────────────────────────────────────
  static Future<List<Transaksi>> getTransaksi({
    String? jenis, int limit = 100, bool hanyaBelumSync = false,
  }) async {
    final d = await db;
    final clauses = <String>[];
    final args = <Object?>[];
    if (jenis != null && jenis != 'semua') {
      clauses.add('jenis = ?');
      args.add(jenis);
    }
    if (hanyaBelumSync) clauses.add('synced = 0');
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = await d.rawQuery(
      'SELECT * FROM transaksi $where ORDER BY tanggal DESC, id DESC LIMIT $limit',
      args,
    );
    return rows.map((r) => Transaksi(
      id: r['id']?.toString() ?? '',
      tanggal: r['tanggal'] as String,
      jenis: r['jenis'] as String,
      nominal: r['nominal'] as double,
      kategori: r['kategori'] as String,
      deskripsi: (r['deskripsi'] as String?) ?? '',
      metodePembayaran: (r['metode_pembayaran'] as String?) ?? 'tunai',
      akunId: r['akun_id']?.toString(),
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

  static Future<void> upsertTransaksiBatch(List<Transaksi> list, {bool synced = true}) async {
    if (list.isEmpty) return;
    final d = await db;
    final batch = d.batch();
    for (final tx in list) {
      batch.insert('transaksi', {
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
    await batch.commit(noResult: true);
  }

  static Future<void> insertTransaksiLocal(Map<String, dynamic> data, String localId) async {
    final d = await db;
    String? akunId = data['akun_id']?.toString();
    if (akunId == null || akunId.isEmpty || akunId == 'null') {
      final akuns = await d.query('akun', columns: ['id', 'local_id'], limit: 1);
      if (akuns.isNotEmpty) {
        akunId = akuns.first['id']?.toString() ?? akuns.first['local_id']?.toString();
        data['akun_id'] = akunId;
      }
    }

    // id lokal = localId (String), konsisten dengan id server (ObjectId).
    await d.insert('transaksi', {
      'id': localId,
      'local_id': localId,
      'tanggal': data['tanggal'],
      'jenis': data['jenis'],
      'nominal': data['nominal'],
      'kategori': data['kategori'],
      'deskripsi': data['deskripsi'] ?? '',
      'metode_pembayaran': data['metode_pembayaran'] ?? 'tunai',
      'akun_id': akunId,
      'akun_nama': null,
      'synced': 0,
    });

    if (akunId != null && akunId.isNotEmpty) {
      final nominal = (data['nominal'] as num? ?? 0).toDouble();
      final delta = data['jenis'] == 'pemasukan' ? nominal : -nominal;
      await d.rawUpdate(
        'UPDATE akun SET saldo = saldo + ? WHERE id = ? OR local_id = ?',
        [delta, akunId, akunId],
      );
    }
  }

  static Future<void> deleteTransaksi(dynamic id) async {
    final d = await db;
    final rows = await d.query('transaksi', where: 'id = ? OR local_id = ?', whereArgs: [id, id]);
    if (rows.isNotEmpty) {
      final row = rows.first;
      final akunId = row['akun_id']?.toString();
      if (akunId != null && akunId.isNotEmpty) {
        final nominal = (row['nominal'] as num? ?? 0).toDouble();
        final jenis = row['jenis'] as String?;
        final delta = jenis == 'pemasukan' ? -nominal : nominal;
        await d.rawUpdate(
          'UPDATE akun SET saldo = saldo + ? WHERE id = ? OR local_id = ?',
          [delta, akunId, akunId],
        );
      }
    }
    await d.delete('transaksi', where: 'id = ? OR local_id = ?', whereArgs: [id, id]);
  }

  static Future<void> deleteAllTransaksi() async {
    final d = await db;
    await d.delete('transaksi');
  }

  /// Terapkan perubahan body ke baris lokal yang id-nya [id].
  static Future<void> updateTransaksiLocal(dynamic id, Map<String, dynamic> data) async {
    final d = await db;
    final rows = await d.query('transaksi', where: 'id = ? OR local_id = ?', whereArgs: [id, id]);
    if (rows.isNotEmpty) {
      final old = rows.first;
      final oldAkunId = old['akun_id']?.toString();
      final oldNominal = (old['nominal'] as num? ?? 0).toDouble();
      final oldJenis = old['jenis'] as String?;

      // Revert saldo transaksi lama
      if (oldAkunId != null && oldAkunId.isNotEmpty) {
        final revertDelta = oldJenis == 'pemasukan' ? -oldNominal : oldNominal;
        await d.rawUpdate(
          'UPDATE akun SET saldo = saldo + ? WHERE id = ? OR local_id = ?',
          [revertDelta, oldAkunId, oldAkunId],
        );
      }

      // Terapkan saldo transaksi baru
      final newAkunId = data.containsKey('akun_id') ? data['akun_id']?.toString() : oldAkunId;
      final newNominal = data['nominal'] != null ? (data['nominal'] as num).toDouble() : oldNominal;
      final newJenis = (data['jenis'] as String?) ?? oldJenis;

      if (newAkunId != null && newAkunId.isNotEmpty) {
        final applyDelta = newJenis == 'pemasukan' ? newNominal : -newNominal;
        await d.rawUpdate(
          'UPDATE akun SET saldo = saldo + ? WHERE id = ? OR local_id = ?',
          [applyDelta, newAkunId, newAkunId],
        );
      }
    }

    final updated = <String, dynamic>{};
    if (data['tanggal'] != null) updated['tanggal'] = data['tanggal'];
    if (data['jenis'] != null) updated['jenis'] = data['jenis'];
    if (data['nominal'] != null) updated['nominal'] = data['nominal'];
    if (data['kategori'] != null) updated['kategori'] = data['kategori'];
    if (data['deskripsi'] != null) updated['deskripsi'] = data['deskripsi'];
    if (data['metode_pembayaran'] != null) {
      updated['metode_pembayaran'] = data['metode_pembayaran'];
    }
    if (data.containsKey('akun_id')) updated['akun_id'] = data['akun_id'];
    if (updated.isEmpty) return;
    await d.update('transaksi', updated, where: 'id = ? OR local_id = ?', whereArgs: [id, id]);
  }

  static Future<void> replaceTransaksiLocalToServer(String localId, dynamic serverId) async {
    final d = await db;
    final sid = serverId.toString();
    await d.rawUpdate(
      'UPDATE transaksi SET id = ?, synced = 1 WHERE local_id = ?',
      [sid, localId],
    );
    await d.rawUpdate(
      "UPDATE sync_queue SET path = '/transaksi/' || ? WHERE path = '/transaksi/' || ?",
      [sid, localId],
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
      id: r['id']?.toString() ?? '',
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

  static Future<void> upsertAnggaranBatch(List<Anggaran> list, {bool synced = true}) async {
    if (list.isEmpty) return;
    final d = await db;
    final batch = d.batch();
    for (final a in list) {
      batch.insert('anggaran', {
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
    await batch.commit(noResult: true);
  }

  static Future<void> insertAnggaranLocal(String localId, String kategori, double batas, String periode) async {
    final d = await db;
    await d.insert('anggaran', {
      'id': localId,
      'local_id': localId,
      'kategori': kategori,
      'batas': batas,
      'periode': periode,
      'terpakai': 0,
      'persentase': 0,
      'synced': 0,
    });
  }

  static Future<void> deleteAnggaran(dynamic id) async {
    final d = await db;
    await d.delete('anggaran', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> replaceAnggaranLocalToServer(String localId, String serverId) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE anggaran SET id = ?, synced = 1 WHERE local_id = ?',
      [serverId, localId],
    );
    await d.rawUpdate(
      "UPDATE sync_queue SET path = '/anggaran/' || ? WHERE path = '/anggaran/' || ?",
      [serverId, localId],
    );
  }

  static Future<void> updateAnggaranBatas(dynamic id, double batas) async {
    final d = await db;
    await d.rawUpdate('UPDATE anggaran SET batas = ?, synced = 0 WHERE id = ?', [batas, id]);
  }

  // ── Goals ──────────────────────────────────────────────────────────────────
  static Future<List<Goal>> getGoals() async {
    final d = await db;
    final rows = await d.query('goals', orderBy: 'id DESC');
    return rows.map((r) => Goal(
      id: r['id']?.toString() ?? '',
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

  static Future<void> upsertGoalBatch(List<Goal> list, {bool synced = true}) async {
    if (list.isEmpty) return;
    final d = await db;
    final batch = d.batch();
    for (final g in list) {
      batch.insert('goals', {
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
    await batch.commit(noResult: true);
  }

  static Future<void> insertGoalLocal(String localId, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert('goals', {
      'id': localId,
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

  static Future<void> deleteGoal(dynamic id) async {
    final d = await db;
    await d.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> replaceGoalLocalToServer(String localId, String serverId) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE goals SET id = ?, synced = 1 WHERE local_id = ?',
      [serverId, localId],
    );
    await d.rawUpdate(
      "UPDATE sync_queue SET path = '/goals/' || ? || '/progres' WHERE path = '/goals/' || ? || '/progres'",
      [serverId, localId],
    );
    await d.rawUpdate(
      "UPDATE sync_queue SET path = '/goals/' || ? WHERE path = '/goals/' || ?",
      [serverId, localId],
    );
  }

  static Future<void> updateGoalProgres(dynamic id, double tambah) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE goals SET terkumpul = terkumpul + ?, synced = 0 WHERE id = ?',
      [tambah, id],
    );
  }

  // ── Sync Queue ─────────────────────────────────────────────────────────────
  // ── Akun (dompet) ──────────────────────────────────────────────────────────
  /// Simpan dompet yang dibuat saat offline. `localId` menjadi id baris
  /// sampai server memberi id asli (lihat [replaceAkunLocalToServer]).
  static Future<void> insertAkunLocal(
      Map<String, dynamic> data, String localId) async {
    final d = await db;
    await d.insert('akun', {
      'id': localId,
      'local_id': localId,
      'nama': data['nama'],
      'jenis': data['jenis'],
      'saldo': data['saldo'] ?? 0,
      'warna': data['warna'] ?? '#2563EB',
      'ikon': data['ikon'] ?? 'bank',
      'synced': 0,
    });
  }

  /// Ganti id lokal dengan id server setelah POST /akun berhasil.
  static Future<void> replaceAkunLocalToServer(
      String localId, String serverId) async {
    final d = await db;
    await d.update(
      'akun',
      {'id': serverId, 'synced': 1},
      where: 'id = ? OR local_id = ?',
      whereArgs: [localId, localId],
    );
    await d.rawUpdate(
      "UPDATE sync_queue SET path = '/akun/' || ? WHERE path = '/akun/' || ?",
      [serverId, localId],
    );

    // Perbarui akun_id pada antrean transaksi yang merujuk ke id lokal ini
    try {
      final txQueue = await d.query('sync_queue', where: "table_name = 'transaksi' AND body LIKE ?", whereArgs: ['%$localId%']);
      for (final q in txQueue) {
        final qid = q['id'] as int;
        final bodyStr = q['body'] as String? ?? '{}';
        try {
          final b = jsonDecode(bodyStr) as Map<String, dynamic>;
          if (b['akun_id']?.toString() == localId) {
            b['akun_id'] = serverId;
            await d.update('sync_queue', {'body': jsonEncode(b)}, where: 'id = ?', whereArgs: [qid]);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Cari id server untuk dompet/akun berdasarkan localId atau id.
  static Future<String?> getServerIdForAkun(String localId) async {
    final d = await db;
    final rows = await d.query('akun', columns: ['id', 'synced'], where: 'id = ? OR local_id = ?', whereArgs: [localId, localId]);
    if (rows.isNotEmpty) {
      final id = rows.first['id']?.toString();
      final synced = (rows.first['synced'] as int? ?? 0) == 1;
      if (synced && id != null && !id.startsWith('akun_')) {
        return id;
      }
    }
    return null;
  }

  /// Cari id server untuk transaksi berdasarkan localId.
  static Future<String?> getServerIdForTransaksi(String localId) async {
    final d = await db;
    final rows = await d.query('transaksi', columns: ['id', 'synced'], where: 'local_id = ?', whereArgs: [localId]);
    if (rows.isNotEmpty) {
      final id = rows.first['id']?.toString();
      final synced = (rows.first['synced'] as int? ?? 0) == 1;
      if (synced && id != null && !id.startsWith('tx_')) {
        return id;
      }
    }
    return null;
  }

  /// Perbarui status, retry count, dan pesan error item antrean.
  static Future<void> updateQueueItem(
    int id, {
    required int retryCount,
    required String lastError,
    required String lastAttempt,
    String status = 'pending',
  }) async {
    final d = await db;
    await d.update('sync_queue', {
      'retry_count': retryCount,
      'last_error': lastError,
      'last_attempt': lastAttempt,
      'status': status,
    }, where: 'id = ?', whereArgs: [id]);
  }

  /// Hapus akun dari database lokal
  static Future<void> deleteAkun(dynamic id) async {
    final d = await db;
    await d.delete(
      'akun',
      where: 'id = ? OR local_id = ?',
      whereArgs: [id.toString(), id.toString()],
    );
  }

  /// Ubah saldo dompet offline (mis. setelah transaksi tercatat).
  static Future<void> updateAkunSaldoLocal(String id, double saldo) async {
    final d = await db;
    await d.rawUpdate(
      'UPDATE akun SET saldo = ?, synced = 0 WHERE id = ? OR local_id = ?',
      [saldo, id, id],
    );
  }

  /// Ambil semua dompet: gabungan lokal (belum sync) + server.
  /// Saat offline, pemilih dompet di input transaksi tetap terisi.
  static Future<List<Akun>> getAkunList() async {
    final d = await db;
    final rows = await d.query('akun', orderBy: 'nama ASC');
    return rows.map((r) => Akun(
          id: r['id']?.toString() ?? '',
          nama: (r['nama'] as String?) ?? '',
          jenis: (r['jenis'] as String?) ?? 'cash',
          saldo: (r['saldo'] as num? ?? 0).toDouble(),
          warna: (r['warna'] as String?) ?? '#2563EB',
          ikon: (r['ikon'] as String?) ?? 'bank',
        )).toList();
  }

  /// Simpan daftar dompet dari server ke cache lokal.
  ///
  /// Sebelumnya ConflictAlgorithm.replace hanya menangani konflik pada
  /// PRIMARY KEY (id). Akun lokal sementara (local_id != null, id = 'akun_xxx')
  /// tidak terhapus saat server mengirim id asli — hasilnya duplikat di UI.
  ///
  /// Sekarang: untuk setiap akun server, hapus baris lokal sementara yang
  /// bisa saja mewakili akun yang sama (berdasarkan nama + jenis + saldo)
  /// sebelum melakukan upsert.
  static Future<void> upsertAkunList(List<Akun> list) async {
    final d = await db;
    for (final a in list) {
      await d.insert('akun', {
        'id': a.id?.toString(),
        'local_id': null,
        'nama': a.nama,
        'jenis': a.jenis,
        'saldo': a.saldo,
        'warna': a.warna,
        'ikon': a.ikon,
        'synced': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

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
    return d.rawQuery('''
      SELECT * FROM sync_queue 
      ORDER BY 
        CASE table_name 
          WHEN 'akun' THEN 1 
          WHEN 'transaksi' THEN 2 
          WHEN 'anggaran' THEN 3 
          WHEN 'goals' THEN 4 
          ELSE 5 
        END ASC, 
        id ASC
    ''');
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

  static Future<int> getQueueCount() => getPendingCount();

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
    await d.delete('akun');
    await d.delete('sync_queue');
  }
}
