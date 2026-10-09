import 'dart:async' show unawaited;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../constants/config.dart';
import '../models/models.dart';
import 'app_events.dart';
import 'app_prefs.dart';
import 'auth_service.dart';
import 'local_db.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';

class ApiService {
  static final _client = http.Client();

  static bool get _online => ConnectivityService.instance.isOnline;

  static Map<String, String> get _authHeaders {
    final token = AuthService.instance.token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Low-level HTTP ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _get(String path, {Duration timeout = const Duration(seconds: 10)}) async {
    try {
      final res = await _client.get(
        Uri.parse('$kApiBaseUrl$path'),
        headers: _authHeaders,
      ).timeout(timeout);
      ConnectivityService.instance.reportOnline();
      if (res.statusCode == 200) return jsonDecode(res.body);
      if (res.statusCode == 401) throw Exception('unauthorized');
      throw Exception('GET $path failed: ${res.statusCode}');
    } catch (e) {
      if (e is! Exception || !e.toString().contains('unauthorized')) {
        ConnectivityService.instance.reportOffline();
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 10)}) async {
    try {
      final res = await _client.post(
        Uri.parse('$kApiBaseUrl$path'),
        headers: _authHeaders,
        body: jsonEncode(body),
      ).timeout(timeout);
      ConnectivityService.instance.reportOnline();
      if (res.statusCode >= 200 && res.statusCode < 300) return jsonDecode(res.body);
      if (res.statusCode == 401) throw Exception('unauthorized');
      throw Exception('POST $path failed: ${res.body}');
    } catch (e) {
      if (e is! Exception || !e.toString().contains('unauthorized')) {
        ConnectivityService.instance.reportOffline();
      }
      rethrow;
    }
  }

  static Future<void> _put(String path, Map<String, dynamic> body, {Duration timeout = const Duration(seconds: 10)}) async {
    try {
      final res = await _client.put(
        Uri.parse('$kApiBaseUrl$path'),
        headers: _authHeaders,
        body: jsonEncode(body),
      ).timeout(timeout);
      ConnectivityService.instance.reportOnline();
      if (res.statusCode >= 200 && res.statusCode < 300) return;
      if (res.statusCode == 401) throw Exception('unauthorized');
      throw Exception('PUT $path failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      if (e is! Exception || !e.toString().contains('unauthorized')) {
        ConnectivityService.instance.reportOffline();
      }
      rethrow;
    }
  }

  static Future<void> _delete(String path, {Duration timeout = const Duration(seconds: 10)}) async {
    try {
      final res = await _client.delete(
        Uri.parse('$kApiBaseUrl$path'),
        headers: _authHeaders,
      ).timeout(timeout);
      ConnectivityService.instance.reportOnline();
      if (res.statusCode >= 200 && res.statusCode < 300) return;
      if (res.statusCode == 401) throw Exception('unauthorized');
      throw Exception('DELETE $path failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      if (e is! Exception || !e.toString().contains('unauthorized')) {
        ConnectivityService.instance.reportOffline();
      }
      rethrow;
    }
  }


  // ── Dashboard ─────────────────────────────────────────────────────────────
  static Future<DashboardData> getDashboard() async {
    if (!_online) throw Exception('offline');
    final data = await _get('/laporan/dashboard');
    return DashboardData.fromJson(data);
  }

  static Future<List<Map<String, dynamic>>> getBulanan() async {
    final data = await _get('/laporan/bulanan');
    return List<Map<String, dynamic>>.from(data['data']);
  }

  // ── Transaksi (offline-aware) ──────────────────────────────────────────────
  /// Ambil transaksi untuk ditampilkan.
  ///
  /// PENTING: baris lokal yang belum terkirim (synced = 0) SELALU ikut
  /// digabung, walau sedang online. Sebelumnya saat online fungsi ini hanya
  /// mengembalikan daftar dari server — kalau upload gagal (permintaan
  /// ditolak atau jaringan putus di tengah), baris lokal tidak terlihat dan
  /// transaksi hasil scan seolah hilang.
  static Future<List<Transaksi>> getTransaksi({
    String? jenis, int limit = 100,
  }) async {
    List<Transaksi> server = [];
    if (_online) {
      try {
        server = await getTransaksiFromServer(jenis: jenis, limit: limit);
        // Update cache lokal (mobile/desktop only)
        if (!kIsWeb) {
          // Simpan salinan server ke cache sekaligus (batch) agar cepat
          await LocalDb.upsertTransaksiBatch(server, synced: true);
        }
      } catch (_) {
        // Gagal ambil dari server → pakai data lokal saja di bawah
      }
    }

    if (kIsWeb) return server;

    // Gabung dengan baris lokal yang belum tersinkron supaya tidak ada
    // transaksi yang "hilang" dari tampilan saat upload belum selesai.
    final pending = await LocalDb.getTransaksi(
      jenis: jenis, limit: limit, hanyaBelumSync: true);

    final idsServer = <String>{ for (final t in server) t.id.toString() };
    final localIdsServer = <String>{ for (final t in server) if (t.localId != null && t.localId!.isNotEmpty) t.localId.toString() };
    final keysServer = <String>{ for (final t in server) _txKey(t) };

    final gabungan = <Transaksi>[
      ...pending.where((t) {
        final idStr = t.id.toString();
        final locStr = (t.localId ?? '').toString();
        if (keysServer.contains(_txKey(t))) return false;
        if (idsServer.contains(idStr)) return false;
        if (locStr.isNotEmpty && (idsServer.contains(locStr) || localIdsServer.contains(locStr))) return false;
        return true;
      }),
      ...server,
    ];

    if (gabungan.isEmpty && !_online) {
      // Offline dan tidak ada pending → tampilkan seluruh cache.
      return LocalDb.getTransaksi(jenis: jenis, limit: limit);
    }
    return gabungan;
  }

  static String _txKey(Transaksi t) => '${t.id}|${t.localId ?? ''}';

  static Future<List<Transaksi>> getTransaksiFromServer({
    String? bulan, String? jenis, int limit = 200,
  }) async {
    var path = '/transaksi?limit=$limit';
    if (bulan != null) path += '&bulan=$bulan';
    if (jenis != null) path += '&jenis=$jenis';
    final data = await _get(path);
    return (data['data'] as List).map((j) => Transaksi.fromJson(j)).toList();
  }

  static Future<Transaksi> createTransaksi(Map<String, dynamic> body) async {
    // Pastikan akun_id selalu terisi dan menunjuk ke dompet yang masih aktif
    if (body['akun_id'] == null || body['akun_id'].toString().isEmpty || body['akun_id'].toString() == 'null') {
      final defaultDompet = AppPrefs.instance.dompetUtama;
      if (!kIsWeb) {
        final akuns = await LocalDb.getAkunList();
        final match = akuns.where((a) => a.id.toString() == defaultDompet);
        if (match.isNotEmpty) {
          body['akun_id'] = match.first.id;
        } else if (akuns.isNotEmpty) {
          body['akun_id'] = akuns.first.id;
          await AppPrefs.instance.setDompetUtama(akuns.first.id.toString());
        }
      }
    }

    // Di web: langsung kirim ke server
    if (kIsWeb) {
      final result = await createTransaksiRaw(body);
      await pullAkun();
      AppEvents.instance.transaksiBerubah();
      AppEvents.instance.akunBerubah();
      return Transaksi.fromJson(result['data']);
    }

    final localId = 'tx_${DateTime.now().millisecondsSinceEpoch}';
    await LocalDb.insertTransaksiLocal(body, localId);
    // Baris lokal sudah tersimpan → beri tahu layar lain sekarang juga (<5ms),
    // sehingga input transaksi terasa instan secepat aplikasi offline murni.
    AppEvents.instance.transaksiBerubah();
    AppEvents.instance.akunBerubah();

    await LocalDb.enqueue(
      method: 'POST', path: '/transaksi',
      body: jsonEncode(body), localId: localId, tableName: 'transaksi',
    );

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }

    return Transaksi(
      id: localId,
      localId: localId,
      tanggal: body['tanggal'] ?? '', jenis: body['jenis'] ?? '',
      nominal: (body['nominal'] as num? ?? 0).toDouble(),
      kategori: body['kategori'] ?? '', deskripsi: body['deskripsi'] ?? '',
      metodePembayaran: body['metode_pembayaran'] ?? 'tunai',
      akunId: body['akun_id']?.toString(),
      synced: false,
    );
  }

  static Future<Map<String, dynamic>> createTransaksiRaw(Map<String, dynamic> body) =>
      _post('/transaksi', body);

  /// POST /akun versi mentah — dipakai SyncService saat mengirim antrean.
  /// Mengembalikan body respons supaya id server bisa diambil dan disimpan.
  static Future<Map<String, dynamic>> createAkunRaw(Map<String, dynamic> body) =>
      _post('/akun', body);

  /// PUT /akun/:id versi mentah — dipakai SyncService.
  static Future<void> updateAkunSaldoRaw(dynamic id, double saldo) =>
      _put('/akun/$id', {'saldo': saldo});

  static Future<void> deleteTransaksi(dynamic id) async {
    if (kIsWeb) {
      if (id != null) {
        try {
          await deleteTransaksiRaw(id);
        } catch (_) {}
      }
      await pullAkun();
      AppEvents.instance.transaksiBerubah();
      AppEvents.instance.akunBerubah();
      return;
    }

    await LocalDb.deleteTransaksi(id);
    AppEvents.instance.transaksiBerubah();
    AppEvents.instance.akunBerubah();

    if (id != null) {
      await LocalDb.enqueue(
        method: 'DELETE', path: '/transaksi/$id',
        body: '{}', localId: 'del_tx_$id', tableName: 'transaksi',
      );
    }

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  /// Hapus beberapa transaksi sekaligus (batch).
  static Future<void> deleteTransaksiBatch(List<dynamic> ids) async {
    if (ids.isEmpty) return;
    if (kIsWeb) {
      for (final id in ids) {
        try {
          if (id != null) await deleteTransaksiRaw(id);
        } catch (_) {}
      }
      await pullAkun();
      AppEvents.instance.transaksiBerubah();
      AppEvents.instance.akunBerubah();
      return;
    }

    for (final id in ids) {
      await LocalDb.deleteTransaksi(id);
      if (id != null) {
        await LocalDb.enqueue(
          method: 'DELETE', path: '/transaksi/$id',
          body: '{}', localId: 'del_tx_$id', tableName: 'transaksi',
        );
      }
    }
    AppEvents.instance.transaksiBerubah();
    AppEvents.instance.akunBerubah();

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  /// Hapus semua transaksi dari lokal dan server.
  static Future<void> deleteAllTransaksi() async {
    if (kIsWeb) {
      try {
        final txs = await getTransaksi(limit: 500);
        for (final t in txs) {
          if (t.id != null) await deleteTransaksiRaw(t.id);
        }
      } catch (_) {}
      await pullAkun();
      AppEvents.instance.transaksiBerubah();
      AppEvents.instance.akunBerubah();
      return;
    }

    await LocalDb.deleteAllTransaksi();
    AppEvents.instance.transaksiBerubah();
    AppEvents.instance.akunBerubah();

    if (_online) {
      try {
        final txs = await getTransaksiFromServer(limit: 500);
        for (final t in txs) {
          if (t.id != null) await deleteTransaksiRaw(t.id);
        }
        await pullAkun();
      } catch (_) {}
    }
  }

  static Future<void> deleteTransaksiRaw(dynamic id) => _delete('/transaksi/$id');

  /// Ubah transaksi yang sudah ada. Offline-aware seperti createTransaksi:
  /// perbarui cache lokal instan (<5ms) lalu antrekan / sync di background.
  static Future<void> updateTransaksi(dynamic id, Map<String, dynamic> body) async {
    if (kIsWeb) {
      await updateTransaksiRaw(id, body);
      await pullAkun();
      AppEvents.instance.transaksiBerubah();
      AppEvents.instance.akunBerubah();
      return;
    }

    // Perbarui baris lokal lebih dulu — perubahan terlihat seketika
    await LocalDb.updateTransaksiLocal(id, body);
    AppEvents.instance.transaksiBerubah();
    AppEvents.instance.akunBerubah();

    await LocalDb.enqueue(
      method: 'PUT', path: '/transaksi/$id',
      body: jsonEncode(body), localId: 'upd_tx_$id', tableName: 'transaksi',
    );

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  static Future<void> updateTransaksiRaw(dynamic id, Map<String, dynamic> body) =>
      _put('/transaksi/$id', body);

  // ── Akun ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAkun() async => _get('/akun');

  /// Normalisasi jenis dompet agar selalu kompatibel dengan backend.
  static String normalizeJenisForServer(String? jenis) {
    final j = (jenis ?? '').toLowerCase().trim();
    switch (j) {
      case 'cashflow':
      case 'kas':
      case 'cash':
        return 'kas';
      case 'tabungan':
      case 'kredit':
      case 'bank':
      case 'saving':
      case 'credit':
        return 'bank';
      case 'ewallet':
      case 'e-wallet':
      case 'gopay':
      case 'ovo':
      case 'dana':
      case 'shopeepay':
        return 'ewallet';
      case 'aset':
      case 'investasi':
      case 'gold':
        return 'investasi';
      default:
        return 'bank';
    }
  }

  /// Simpan saldo (akun) baru. Dipakai layar Tambah Saldo.
  static Future<void> createAkun({
    required String nama,
    required String jenis,
    double saldo = 0,
    String warna = '#2563EB',
    double? targetNominal,
    String? targetTanggal,
    double? limitKartu,
    int? tglCetak,
    int? tglTempo,
    double? gram,
    double? hargaBeliPerGram,
  }) async {
    final localId = 'akun_${DateTime.now().millisecondsSinceEpoch}';
    final serverJenis = normalizeJenisForServer(jenis);
    final body = {
      'nama': nama,
      'jenis': serverJenis,
      'saldo': saldo,
      'warna': warna,
      'ikon': jenis,
      'local_id': localId,
      if (targetNominal != null) 'target_nominal': targetNominal,
      if (targetTanggal != null) 'target_tanggal': targetTanggal,
      if (limitKartu != null) 'limit_kartu': limitKartu,
      if (tglCetak != null) 'tgl_cetak': tglCetak,
      if (tglTempo != null) 'tgl_tempo': tglTempo,
      if (gram != null) 'gram': gram,
      if (hargaBeliPerGram != null) 'harga_beli_per_gram': hargaBeliPerGram,
    };

    if (kIsWeb) {
      if (!_online) throw Exception('Tidak ada koneksi ke server.');
      await _post('/akun', body);
      AppEvents.instance.akunBerubah();
      return;
    }

    // Simpan lokal instan (<5ms)
    await LocalDb.insertAkunLocal(body, localId);
    final currentUtama = AppPrefs.instance.dompetUtama;
    final akuns = await LocalDb.getAkunList();
    final exists = akuns.any((a) => a.id.toString() == currentUtama);
    if (!exists || currentUtama == null || currentUtama.isEmpty) {
      await AppPrefs.instance.setDompetUtama(localId);
    }
    AppEvents.instance.akunBerubah();

    await LocalDb.enqueue(
      method: 'POST', path: '/akun',
      body: jsonEncode(body), localId: localId,
      tableName: 'akun',
    );

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  /// Ubah saldo sebuah dompet/akun.
  static Future<void> updateAkunSaldo(dynamic id, double saldo) async {
    if (kIsWeb) {
      if (!_online) throw Exception('Tidak ada koneksi ke server.');
      await _put('/akun/$id', {'saldo': saldo});
      AppEvents.instance.akunBerubah();
      return;
    }

    await LocalDb.updateAkunSaldoLocal(id.toString(), saldo);
    AppEvents.instance.akunBerubah();

    await LocalDb.enqueue(
      method: 'PUT', path: '/akun/$id',
      body: jsonEncode({'saldo': saldo}), localId: 'upd_akun_$id',
      tableName: 'akun',
    );

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  static Future<void> deleteAkun(dynamic id) async {
    final idStr = id?.toString();
    if (idStr != null) {
      final prefs = AppPrefs.instance;
      if (prefs.dompetUtama == idStr) {
        await prefs.setDompetUtama(null);
      }
      final tampil = List<String>.from(prefs.dompetTampil);
      if (tampil.contains(idStr)) {
        tampil.remove(idStr);
        await prefs.setDompetTampil(tampil);
      }
    }

    if (kIsWeb) {
      if (id != null && _online) {
        try {
          await deleteAkunRaw(id);
        } catch (_) {}
      }
      AppEvents.instance.akunBerubah();
      return;
    }

    if (id != null) {
      await LocalDb.deleteAkun(id);
    }
    AppEvents.instance.akunBerubah();

    if (id != null) {
      await LocalDb.enqueue(
        method: 'DELETE', path: '/akun/$id',
        body: '{}', localId: 'del_akun_$id', tableName: 'akun',
      );
    }

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  static Future<void> deleteAkunRaw(dynamic id) => _delete('/akun/$id');

  /// Tarik ulang daftar akun (dompet) dari server dan simpan ke cache.
  /// Dipakai setelah operasi transaksi, karena backend mengubah saldo
  /// akun di sisi server — app harus tahu saldo barunya.
  /// Hanya picu AppEvents.akunBerubah() jika data benar-benar berubah.
  static Future<void> pullAkun() async {
    if (kIsWeb) return;
    if (!ConnectivityService.instance.isOnline) return;
    try {
      final data = await _get('/akun');
      final newList = (data['data'] as List).map((j) => Akun.fromJson(j)).toList();
      
      // Ambil daftar akun lama sebelum upsert
      final oldList = await LocalDb.getAkunList();
      
      // Upsert ke cache lokal
      await LocalDb.upsertAkunList(newList);
      
      // Bandingkan apakah ada perubahan signifikan
      if (_akunListChanged(oldList, newList)) {
        // Menu Saldo & beranda mendengarkan AppEvents.akun, jadi beri tahu
        // bahwa saldo dompet sudah berubah.
        AppEvents.instance.akunBerubah();
      }
    } catch (_) {
      // Server gagal → cache lama tetap dipakai
    }
  }

  static Future<List<Akun>> getAkunList() async {
    if (kIsWeb) {
      // Web tidak punya cache lokal — ambil langsung dari server.
      if (!_online) return [];
      final data = await _get('/akun');
      return (data['data'] as List).map((j) => Akun.fromJson(j)).toList();
    }

    // Mobile/desktop: simpan hasil server ke cache, lalu gabung dengan
    // dompet lokal yang belum tersinkron supaya pemilih dompet tidak
    // kosong saat sebagian operasi masih ada di antrean.
    if (_online) {
      try {
        final data = await _get('/akun');
        final newList = (data['data'] as List)
            .map((j) => Akun.fromJson(j))
            .toList();
        
        // Ambil daftar akun lama sebelum upsert
        final oldList = await LocalDb.getAkunList();
        
        await LocalDb.upsertAkunList(newList);
        
        // Hanya trigger event jika ada perubahan
        if (_akunListChanged(oldList, newList)) {
          AppEvents.instance.akunBerubah();
        }
      } catch (_) {
        // Server gagal → pakai cache saja di bawah
        // Tidak perlu trigger event karena data tidak berubah
      }
    }
    return LocalDb.getAkunList();
  }

  // ── Anggaran (offline-aware) ───────────────────────────────────────────────
  static Future<List<Anggaran>> getAnggaran(String periode) async {
    if (_online) {
      try {
        final list = await getAnggaranFromServer(periode);
        if (!kIsWeb) {
          await LocalDb.upsertAnggaranBatch(list, synced: true);
        }
        return list;
      } catch (_) {}
    }
    if (kIsWeb) return [];
    return LocalDb.getAnggaran(periode);
  }

  static Future<List<Anggaran>> getAnggaranFromServer(String periode) async {
    final data = await _get('/anggaran?periode=$periode');
    return (data['data'] as List).map((j) => Anggaran.fromJson(j)).toList();
  }

  static Future<void> createAnggaran(String kategori, double batas, String periode) async {
    if (kIsWeb) {
      await createAnggaranRaw(kategori, batas, periode);
      AppEvents.instance.anggaranBerubah();
      return;
    }
    final localId = 'ang_${DateTime.now().millisecondsSinceEpoch}';
    await LocalDb.insertAnggaranLocal(localId, kategori, batas, periode);
    AppEvents.instance.anggaranBerubah();

    await LocalDb.enqueue(
      method: 'POST', path: '/anggaran',
      body: jsonEncode({'kategori': kategori, 'batas': batas, 'periode': periode}),
      localId: localId, tableName: 'anggaran',
    );

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  static Future<Map<String, dynamic>> createAnggaranRaw(String kategori, double batas, String periode) =>
      _post('/anggaran', {'kategori': kategori, 'batas': batas, 'periode': periode});

  static Future<void> updateAnggaran(dynamic id, double batas) async {
    if (kIsWeb) {
      await updateAnggaranRaw(id, batas);
      AppEvents.instance.anggaranBerubah();
      return;
    }
    await LocalDb.updateAnggaranBatas(id, batas);
    AppEvents.instance.anggaranBerubah();

    await LocalDb.enqueue(
      method: 'PUT', path: '/anggaran/$id',
      body: jsonEncode({'batas': batas}), localId: 'upd_ang_$id', tableName: 'anggaran',
    );

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  static Future<void> updateAnggaranRaw(dynamic id, double batas) =>
      _put('/anggaran/$id', {'batas': batas});

  static Future<void> deleteAnggaran(dynamic id) async {
    if (kIsWeb) {
      await deleteAnggaranRaw(id);
      AppEvents.instance.anggaranBerubah();
      return;
    }
    await LocalDb.deleteAnggaran(id);
    AppEvents.instance.anggaranBerubah();

    if (id != null) {
      await LocalDb.enqueue(
        method: 'DELETE', path: '/anggaran/$id',
        body: '{}', localId: 'del_ang_$id', tableName: 'anggaran',
      );
    }

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  static Future<void> deleteAnggaranRaw(dynamic id) => _delete('/anggaran/$id');

  // ── Goals (offline-aware) ──────────────────────────────────────────────────
  static Future<List<Goal>> getGoals() async {
    if (_online) {
      try {
        final list = await getGoalsFromServer();
        if (!kIsWeb) {
          await LocalDb.upsertGoalBatch(list, synced: true);
        }
        return list;
      } catch (_) {}
    }
    if (kIsWeb) return [];
    return LocalDb.getGoals();
  }

  static Future<List<Goal>> getGoalsFromServer() async {
    final data = await _get('/goals');
    return (data['data'] as List).map((j) => Goal.fromJson(j)).toList();
  }

  static Future<void> createGoal(Map<String, dynamic> body) async {
    if (kIsWeb) {
      await createGoalRaw(body);
      AppEvents.instance.goalsBerubah();
      return;
    }
    final localId = 'goal_${DateTime.now().millisecondsSinceEpoch}';
    await LocalDb.insertGoalLocal(localId, body);
    AppEvents.instance.goalsBerubah();

    await LocalDb.enqueue(
      method: 'POST', path: '/goals',
      body: jsonEncode(body), localId: localId, tableName: 'goals',
    );

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  static Future<Map<String, dynamic>> createGoalRaw(Map<String, dynamic> body) =>
      _post('/goals', body);

  static Future<void> updateProgres(dynamic id, double tambah) async {
    if (kIsWeb) {
      await updateProgresRaw(id, tambah);
      AppEvents.instance.goalsBerubah();
      return;
    }
    await LocalDb.updateGoalProgres(id, tambah);
    AppEvents.instance.goalsBerubah();

    await LocalDb.enqueue(
      method: 'PUT', path: '/goals/$id/progres',
      body: jsonEncode({'tambah': tambah}), localId: 'upd_goal_$id', tableName: 'goals',
    );

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  static Future<void> updateProgresRaw(dynamic id, double tambah) =>
      _put('/goals/$id/progres', {'tambah': tambah});

  static Future<void> deleteGoal(dynamic id) async {
    if (kIsWeb) {
      await deleteGoalRaw(id);
      AppEvents.instance.goalsBerubah();
      return;
    }
    await LocalDb.deleteGoal(id);
    AppEvents.instance.goalsBerubah();

    if (id != null) {
      await LocalDb.enqueue(
        method: 'DELETE', path: '/goals/$id',
        body: '{}', localId: 'del_goal_$id', tableName: 'goals',
      );
    }

    if (_online) {
      unawaited(SyncService.instance.syncToServer(force: true));
    }
  }

  static Future<void> deleteGoalRaw(dynamic id) => _delete('/goals/$id');

  // ── AI Chat ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> chat(String pesan) async {
    final t = pesan.trim();
    if (t.isEmpty) {
      return {
        'tipe': 'jawaban',
        'pesan': 'Silakan tulis pertanyaan seputar keuangan atau perintah catat transaksi.'
      };
    }

    final lower = t.toLowerCase();

    // 1. Fast Standalone Greeting / Ping (<1ms response)
    // Hanya berlaku jika pesan HANYA berisi kata sapaan/tes singkat (bukan kalimat panjang)
    if (_isStandaloneGreeting(lower)) {
      return {
        'tipe': 'jawaban',
        'pesan': '👋 Halo! Saya **MengFin AI** siap membantu.\n\nKamu bisa:\n• Tanya kondisi keuangan atau saldo (*"berapa saldo saya?"*)\n• Cek pengeluaran kategori (*"berapa pengeluaran makan bulan ini?"*)\n• Minta tips hemat (*"tips hemat bulan ini"*)\n• Catat transaksi instan (misal: *"beli kopi 20rb"* atau *"gajian 5jt"*)\n\nAda yang ingin ditanyakan atau dicatat? 😊'
      };
    }

    // 2. Fast Transaction Record Command (<1ms response)
    // Hanya berlaku jika MURNI perintah catat transaksi (bukan pertanyaan/konsultasi)
    if (_isTransactionText(lower)) {
      final parsed = _fastParseTransaksiLocal(t);
      if (parsed != null && ((parsed['nominal'] as num?)?.toDouble() ?? 0) > 0) {
        final nominalNum = (parsed['nominal'] as num).toDouble();
        final nominalFmt = _formatRp(nominalNum);
        return {
          'tipe': 'transaksi_preview',
          'data': parsed,
          'pesan': 'Saya mendeteksi transaksi:\n*${parsed['deskripsi']}*\n💰 Rp $nominalFmt\n📁 ${parsed['kategori']}\n💳 ${parsed['metode_pembayaran']}\n\nKonfirmasi untuk menyimpan?'
        };
      }
    }

    // 3. Online Server AI Query dengan timeout responsif (20 detik)
    if (_online) {
      try {
        final res = await _post(
          '/ai/chat',
          {'pesan': t},
          timeout: const Duration(seconds: 20),
        );
        if (res.containsKey('tipe') || res.containsKey('pesan')) {
          final pesanText = res['pesan']?.toString() ?? '';
          if (!pesanText.contains('tidak bisa memproses') &&
              !pesanText.contains('terjadi kendala saat') &&
              !pesanText.contains('Error') &&
              pesanText.trim().isNotEmpty) {
            return res;
          }
        }
      } catch (_) {
        // Timeout / server offline → alihkan ke fallback lokal seketika
      }
    }

    return _localAIChat(t);
  }

  static bool _isStandaloneGreeting(String lower) {
    final clean = lower.replaceAll(RegExp(r'[!.,?~]+'), '').trim();
    const greetings = [
      'halo', 'hai', 'hi', 'hey', 'hei', 'tes', 'test', 'ping', 'p',
      'pagi', 'selamat pagi', 'siang', 'selamat siang', 'sore', 'selamat sore',
      'malam', 'selamat malam', 'assalamualaikum', 'halo mengfin', 'hai mengfin'
    ];
    return greetings.contains(clean);
  }

  static Future<Map<String, dynamic>> _localAIChat(String pesan) async {
    try {
      final t = pesan.trim();
      final lower = t.toLowerCase();

      // Ambil data lokal untuk analisis keuangan
      final now = DateTime.now();
      final bulanIni = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      Map<String, double> dash = {};
      List<Transaksi> txList = [];
      List<Akun> akuns = [];
      List<Anggaran> anggarans = [];

      if (!kIsWeb) {
        try {
          dash = await LocalDb.getDashboardLocal(bulanIni);
          txList = await LocalDb.getTransaksi(limit: 50);
          akuns = await LocalDb.getAkunList();
          anggarans = await LocalDb.getAnggaran(bulanIni);
        } catch (_) {}
      }

      final double saldoTotal = akuns.fold<double>(0.0, (s, a) => s + a.saldo);
      final double pemasukan = (dash['pemasukan'] ??
          txList.where((x) => x.jenis == 'pemasukan' && x.tanggal.startsWith(bulanIni)).fold<double>(0.0, (s, x) => s + x.nominal)).toDouble();
      final double pengeluaran = (dash['pengeluaran'] ??
          txList.where((x) => x.jenis == 'pengeluaran' && x.tanggal.startsWith(bulanIni)).fold<double>(0.0, (s, x) => s + x.nominal)).toDouble();
      final double saldoBersih = pemasukan - pengeluaran;
      final double rataHarian = now.day > 0 ? (pengeluaran / now.day) : 0.0;
      final double pengeluaranHariIni = txList
          .where((x) => x.jenis == 'pengeluaran' && x.tanggal == todayStr)
          .fold<double>(0.0, (s, x) => s + x.nominal);

      // Kategori pengeluaran bulan ini
      final katMap = <String, double>{};
      final katCount = <String, int>{};
      final katItems = <String, List<Transaksi>>{};

      for (final x in txList.where((x) => x.jenis == 'pengeluaran' && x.tanggal.startsWith(bulanIni))) {
        katMap[x.kategori] = (katMap[x.kategori] ?? 0.0) + x.nominal;
        katCount[x.kategori] = (katCount[x.kategori] ?? 0) + 1;
        katItems.putIfAbsent(x.kategori, () => []).add(x);
      }
      final topKat = katMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

      // ── INTENT 1: Tanya Pengeluaran Kategori Spesifik ──────────────────
      final matchedCategory = _detectCategoryIntent(lower);
      if (matchedCategory != null) {
        final totalKat = katMap[matchedCategory] ?? 0.0;
        final countKat = katCount[matchedCategory] ?? 0;
        final items = katItems[matchedCategory] ?? [];
        final anggaranKat = anggarans.where((a) => a.kategori.toLowerCase() == matchedCategory.toLowerCase()).firstOrNull;

        final sb = StringBuffer();
        sb.writeln('📁 **Pengeluaran Kategori: $matchedCategory ($bulanIni)**\n');
        sb.writeln('• Total Pengeluaran : **Rp ${_formatRp(totalKat)}**');
        sb.writeln('• Frekuensi Transaksi: **$countKat transaksi**');
        if (anggaranKat != null && anggaranKat.batas > 0) {
          final pct = ((totalKat / anggaranKat.batas) * 100).round();
          sb.writeln('• Batas Budget : Rp ${_formatRp(anggaranKat.batas)} ($pct%)');
          if (totalKat > anggaranKat.batas) {
            sb.writeln('• Status: ⚠️ Melebihi batas anggaran!');
          } else {
            sb.writeln('• Sisa Budget: Rp ${_formatRp(anggaranKat.batas - totalKat)} (Aman ✅)');
          }
        }
        if (items.isNotEmpty) {
          sb.writeln('\n**Rincian Transaksi:**');
          for (final item in items.take(5)) {
            sb.writeln('  • ${item.deskripsi.isNotEmpty ? item.deskripsi : item.kategori} — Rp ${_formatRp(item.nominal)} (${item.tanggal})');
          }
        } else {
          sb.writeln('\n*Belum ada transaksi di kategori ini pada bulan $bulanIni.*');
        }
        return {'tipe': 'jawaban', 'pesan': sb.toString()};
      }

      // ── INTENT 2: Tanya Budget & Anggaran ──────────────────────────────
      if (lower.contains('budget') || lower.contains('anggaran') || lower.contains('limit') || lower.contains('batas pengeluaran')) {
        if (anggarans.isEmpty) {
          return {
            'tipe': 'jawaban',
            'pesan': '🎯 **Status Budget:**\n\n• Pengeluaran Hari Ini: **Rp ${_formatRp(pengeluaranHariIni)}**\n• Rata-rata Harian: **Rp ${_formatRp(rataHarian)}/hari**\n\n*Kamu belum menetapkan batas anggaran kategori. Atur batas budget di tab Saldo/Budget agar pengeluaran terkontrol.*'
          };
        }
        final sb = StringBuffer();
        sb.writeln('🎯 **Status Anggaran Kategori ($bulanIni):**\n');
        for (final a in anggarans) {
          final terpakai = katMap[a.kategori] ?? 0.0;
          final pct = (terpakai / (a.batas > 0 ? a.batas : 1) * 100).round();
          final statusIcon = terpakai > a.batas ? '⚠️' : '✅';
          sb.writeln('$statusIcon **${a.kategori}**: Rp ${_formatRp(terpakai)} / Rp ${_formatRp(a.batas)} ($pct%)');
        }
        return {'tipe': 'jawaban', 'pesan': sb.toString()};
      }

      // ── INTENT 3: Pengeluaran Hari Ini ─────────────────────────────────
      if (lower.contains('hari ini') || lower.contains('today') || lower.contains('pengeluaran hari ini')) {
        final todayTxs = txList.where((x) => x.tanggal == todayStr).toList();
        final sb = StringBuffer();
        sb.writeln('📅 **Status Pengeluaran Hari Ini ($todayStr):**\n');
        sb.writeln('• Total Pengeluaran: **Rp ${_formatRp(pengeluaranHariIni)}**');
        sb.writeln('• Rata-rata Harian Bulan Ini: **Rp ${_formatRp(rataHarian)}/hari**');
        if (todayTxs.isNotEmpty) {
          sb.writeln('\n**Transaksi Hari Ini:**');
          for (final tx in todayTxs) {
            final sign = tx.jenis == 'pemasukan' ? '(+) ' : '(-) ';
            sb.writeln('  • $sign${tx.deskripsi.isNotEmpty ? tx.deskripsi : tx.kategori} — Rp ${_formatRp(tx.nominal)} (${tx.kategori})');
          }
        } else {
          sb.writeln('\n*Belum ada pengeluaran atau pemasukan yang dicatat hari ini.*');
        }
        return {'tipe': 'jawaban', 'pesan': sb.toString()};
      }

      // ── INTENT 4: Tanya Saldo & Dompet ─────────────────────────────────
      if (lower.contains('saldo') || lower.contains('dompet') || lower.contains('uangku') || lower.contains('sisa uang') || lower.contains('rekening') || lower.contains('tabungan')) {
        final sb = StringBuffer();
        sb.writeln('💰 **Informasi Saldo & Dompet:**\n');
        sb.writeln('• Total Saldo Seluruh Dompet: **Rp ${_formatRp(saldoTotal)}**');
        sb.writeln('• Pemasukan Bulan Ini: **Rp ${_formatRp(pemasukan)}**');
        sb.writeln('• Pengeluaran Bulan Ini: **Rp ${_formatRp(pengeluaran)}**');
        sb.writeln('• Arus Kas Bersih (Net): **${saldoBersih >= 0 ? '+' : ''}Rp ${_formatRp(saldoBersih)}** (${saldoBersih >= 0 ? 'Surplus ✅' : 'Defisit ⚠️'})');
        if (akuns.isNotEmpty) {
          sb.writeln('\n**Rincian per Dompet:**');
          for (final a in akuns) {
            sb.writeln('  • **${a.nama}**: Rp ${_formatRp(a.saldo)}');
          }
        }
        return {'tipe': 'jawaban', 'pesan': sb.toString()};
      }

      // ── INTENT 5: Riwayat / Daftar Transaksi Terakhir ────────────────────
      if (lower.contains('riwayat transaksi') || lower.contains('daftar transaksi') || lower.contains('transaksi terakhir') || lower.contains('mutasi') || lower.contains('beli apa saja') || lower.contains('histori')) {
        if (txList.isEmpty) {
          return {
            'tipe': 'jawaban',
            'pesan': '📝 **Riwayat Transaksi:**\n\nBelum ada transaksi tercatat. Ketik misalnya *"beli kopi 25rb"* untuk mencatat transaksi pertamamu!'
          };
        }
        final sb = StringBuffer();
        sb.writeln('📝 **${txList.take(7).length} Transaksi Terakhir:**\n');
        int idx = 1;
        for (final tx in txList.take(7)) {
          final sign = tx.jenis == 'pemasukan' ? '(+) ' : '(-) ';
          sb.writeln('$idx. **${tx.deskripsi.isNotEmpty ? tx.deskripsi : tx.kategori}** — $sign Rp ${_formatRp(tx.nominal)}');
          sb.writeln('   📅 ${tx.tanggal} • 📁 ${tx.kategori}');
          idx++;
        }
        return {'tipe': 'jawaban', 'pesan': sb.toString()};
      }

      // ── INTENT 6: Tips Hemat & Penghematan ──────────────────────────────
      if (lower.contains('tips') || lower.contains('hemat') || lower.contains('kurangi') || lower.contains('berhemat') || lower.contains('strategi')) {
        final sb = StringBuffer();
        sb.writeln('💡 **Tips Hemat Terarah untuk Keuanganmu:**\n');
        if (topKat.isNotEmpty) {
          sb.writeln('1. **Kendalikan Pos ${topKat.first.key}**: Pos ini menjadi pengeluaran terbesarmu (**Rp ${_formatRp(topKat.first.value)}**). Buat batas mingguan ketat untuk pos ini.');
        } else {
          sb.writeln('1. **Catat Pengeluaran Rutin**: Awasi setiap pengeluaran kecil agar tidak terjadi kebocoran halus.');
        }
        sb.writeln('2. **Evaluasi Pengeluaran Harian**: Rata-rata pengeluaranmu saat ini **Rp ${_formatRp(rataHarian)}/hari**.');
        sb.writeln('3. **Pay Yourself First**: Sisihkan minimal 10-20% saat menerima pemasukan langsung ke tabungan/goals.');
        sb.writeln('4. **Gunakan Aturan 24 Jam**: Tunda pembelian barang non-primer selama 24 jam sebelum memutuskan beli.');
        return {'tipe': 'jawaban', 'pesan': sb.toString()};
      }

      // ── INTENT 7: Konsep Finansial (Dana Darurat, Investasi, 50/30/20) ──
      if (lower.contains('dana darurat') || lower.contains('darurat')) {
        final targetDarurat = pengeluaran > 0 ? pengeluaran * 3 : 15000000.0;
        return {
          'tipe': 'jawaban',
          'pesan': '🛡️ **Panduan Dana Darurat:**\n\n• **Tujuan**: Cadangan likuid untuk situasi tak terduga (medis, PHK, perbaikan mendesak).\n• **Rekomendasi Ideal**: 3 - 6 kali pengeluaran bulananmu (sekitar **Rp ${_formatRp(targetDarurat)}**).\n• **Tempat Penyimpanan**: Simpan di instrumen likuid & aman seperti Rekening Terpisah atau Reksadana Pasar Uang.'
        };
      }

      if (lower.contains('investasi') || lower.contains('saham') || lower.contains('reksadana') || lower.contains('crypto') || lower.contains('emas') || lower.contains('deposito')) {
        return {
          'tipe': 'jawaban',
          'pesan': '📈 **Panduan Investasi Pemula:**\n\n1. **Pastikan Fondasi Kuat**: Lunasi utang konsumtif dan miliki dana darurat sebelum mulai berinvestasi.\n2. **Instrumen Rendah Risiko**: Reksadana Pasar Uang (RPU) & Deposito untuk jangka pendek (< 1 tahun).\n3. **Instrumen Menengah/Panjang**: Reksadana Obligasi, Saham Indeks (IHSG/LQ45), atau Emas Fisik untuk jangka > 3 tahun.\n4. **Diversifikasi**: Jangan taruh semua modal dalam satu jenis instrumen.'
        };
      }

      if (lower.contains('50/30/20') || lower.contains('50 30 20') || lower.contains('alokasi')) {
        final incomeBase = pemasukan > 0 ? pemasukan : (saldoTotal > 0 ? saldoTotal : 5000000.0);
        return {
          'tipe': 'jawaban',
          'pesan': '📊 **Metode Alokasi Budget 50/30/20:**\n\nDari pemasukanmu (**Rp ${_formatRp(incomeBase)}**):\n• **50% Kebutuhan Pokok (Needs)** : Rp ${_formatRp(incomeBase * 0.5)} (Makan, Kos, Listrik, Transport)\n• **30% Keinginan (Wants)** : Rp ${_formatRp(incomeBase * 0.3)} (Hiburan, Jajan, Hobi, Liburan)\n• **20% Tabungan & Investasi (Savings)**: Rp ${_formatRp(incomeBase * 0.2)} (Dana darurat, Investasi, Goals)'
        };
      }

      // ── INTENT 8: Bantuan & Fitur Aplikasi ──────────────────────────────
      if (lower.contains('fitur') || lower.contains('cara pakai') || lower.contains('bisa apa') || lower.contains('bantuan') || lower.contains('panduan')) {
        return {
          'tipe': 'jawaban',
          'pesan': '📱 **Fitur Utama MengFin:**\n\n1. **Catat Transaksi Instan**: Ketik langsung di chat (*"beli kopi 25rb"*) atau tekan tombol **(+)**.\n2. **Scan Struk AI**: Foto struk belanja dan data otomatis terinput.\n3. **Multi-Dompet (Saldo)**: Kelola rekening bank, e-wallet, dan uang tunai terpisah.\n4. **Budgeting Pintar**: Pantau batas pengeluaran per kategori secara real-time.\n5. **Laporan & Ekspor**: Ekspor data keuangan ke CSV, Excel, atau PDF di tab View.'
        };
      }

      // ── INTENT 9: Sapaan Ramah / Penutup ────────────────────────────────
      if (lower.contains('terima kasih') || lower.contains('makasih') || lower.contains('thanks') || lower == 'ok' || lower == 'siap' || lower == 'mantap') {
        return {
          'tipe': 'jawaban',
          'pesan': 'Sama-sama! Senang bisa membantu mengelola keuanganmu. Jika ada yang ingin dicek atau dicatat lagi, kabari saya ya! 😊'
        };
      }

      // ── INTENT 10: Hapus Transaksi Terpandu ────────────────────────────
      if (lower.contains('hapus') || lower.contains('batalkan') || lower.contains('delete')) {
        if (txList.isEmpty) {
          return {
            'tipe': 'jawaban',
            'pesan': 'Belum ada transaksi yang bisa dihapus.',
            'saran': ['Catat Transaksi', 'Cek Saldo'],
          };
        }
        final lastTx = txList.first;
        final isIncome = lastTx.jenis == 'pemasukan';
        final sign = isIncome ? '(+)' : '(-)';
        return {
          'tipe': 'hapus_preview',
          'data': {'id': lastTx.id, 'deskripsi': lastTx.deskripsi, 'nominal': lastTx.nominal},
          'pesan': 'Apakah kamu ingin menghapus transaksi terakhir ini?\n\n• **${lastTx.deskripsi.isNotEmpty ? lastTx.deskripsi : lastTx.kategori}**\n• Nominal: $sign Rp ${_formatRp(lastTx.nominal)}\n• Tanggal: ${lastTx.tanggal}\n\nKonfirmasi di bawah:',
          'saran': ['Batal'],
        };
      }

      // ── INTENT 11: Panduan Fitur Spesifik ──────────────────────────────
      if (lower.contains('scan') || lower.contains('struk')) {
        return {
          'tipe': 'jawaban',
          'pesan': '📸 **Cara Scan Struk & Bukti Transfer:**\n\n1. Buka fitur **Scan Struk** dari tombol aksi cepat di Beranda.\n2. Pilih mode **"Struk Belanja"** atau **"Bukti Transfer"**.\n3. Foto struk atau pilih screenshot dari galeri.\n4. Sistem akan mengekstrak total, toko, dan tanggal otomatis on-device & via AI.\n5. Periksa data lalu tekan **Simpan Transaksi**.',
          'saran': ['Cek Saldo', 'Tips Hemat'],
        };
      }

      if (lower.contains('auto catat') || lower.contains('notifikasi') || lower.contains('m-banking')) {
        return {
          'tipe': 'jawaban',
          'pesan': '🔔 **Cara Mengaktifkan Auto-Catat Notifikasi:**\n\n1. Buka menu **Lainnya** -> **Auto-catat dari notifikasi**.\n2. Nyalakan saklar **"Aktifkan"** dan ikuti wizard izin Android.\n3. Berikan izin **Akses Notifikasi** untuk MengFin di pengaturan HP.\n4. Setiap transaksi transfer/QRIS dari GoPay, OVO, DANA, BCA, BRI, Mandiri, dll akan otomatis masuk ke Inbox Transaksi.',
          'saran': ['Inbox Notifikasi', 'Cek Saldo'],
        };
      }

      if (lower.contains('tema') || lower.contains('mode gelap') || lower.contains('musim')) {
        return {
          'tipe': 'jawaban',
          'pesan': '🎨 **Pengaturan Tema & Musim:**\n\n1. Buka menu **Lainnya** di bagian kanan bawah.\n2. Kamu bisa beralih antara **Mode Gelap** dan **Mode Terang**.\n3. Pilih **Tema Musim** (Default, Semi, Panas, Gugur, Dingin) untuk mengganti palet warna aksen & partikel latar belakang.',
          'saran': ['Gimana kondisi keuanganku?', 'Tips Hemat'],
        };
      }

      // ── INTENT 12: Pengaturan Gaya Bahasa ──────────────────────────────
      if (lower.contains('bahasa gaul') || lower.contains('gaya gaul') || lower.contains('santai')) {
        return {
          'tipe': 'jawaban',
          'pesan': 'Siap bos! Mulai sekarang saya bakal ngobrol santai ala bahasa gaul 😎 Ada yang mau dicatat atau dicek lagi?',
          'saran': ['Berapa saldo gue?', 'Tips hemat dong', 'Beli kopi 25rb'],
        };
      }

      if (lower.contains('bahasa formal') || lower.contains('bahasa baku') || lower.contains('sopan')) {
        return {
          'tipe': 'jawaban',
          'pesan': 'Baik, preferensi bahasa formal telah diterapkan. Saya siap membantu mengelola keuangan Anda dengan profesional.',
          'saran': ['Berapa saldo saya?', 'Analisis keuangan saya', 'Tips hemat bulan ini'],
        };
      }

      // ── INTENT 13: Analisis & Ringkasan Keuangan Eksplisit ──────────────
      if (lower.contains('analisis') || lower.contains('ringkasan') || lower.contains('laporan') || lower.contains('kondisi') || lower.contains('insight') || lower.contains('rekap') || lower.contains('evaluasi')) {
        final sb = StringBuffer();
        sb.writeln('📊 **Analisis Keuangan (${bulanIni}):**\n');
        sb.writeln('• **Saldo Dompet**: Rp ${_formatRp(saldoTotal)}');
        sb.writeln('• **Total Pemasukan**: Rp ${_formatRp(pemasukan)}');
        sb.writeln('• **Total Pengeluaran**: Rp ${_formatRp(pengeluaran)}');
        sb.writeln('• **Arus Kas Bersih**: ${saldoBersih >= 0 ? '✅ Surplus ' : '⚠️ Defisit '}Rp ${_formatRp(saldoBersih)}');
        if (topKat.isNotEmpty) {
          sb.writeln('\n📈 **Pengeluaran Terbesar Saat Ini:**');
          for (final k in topKat.take(3)) {
            final pct = pengeluaran > 0 ? (k.value / pengeluaran * 100).round() : 0;
            sb.writeln('  • **${k.key}**: Rp ${_formatRp(k.value)} ($pct%)');
          }
        }
        sb.writeln('\n🎯 **Rekomendasi Aksi:**');
        if (saldoBersih < 0) {
          sb.writeln('• Arus kas bulan ini mengalami defisit. Tekan pos sekunder untuk mengembalikan stabilitas saldo.');
        } else {
          sb.writeln('• Arus kas terjaga positif. Pastikan 10-20% surplus dialokasikan ke pos tabungan/investasi.');
        }

        return {
          'tipe': 'jawaban',
          'pesan': sb.toString(),
          'saran': ['Tips hemat', 'Cek budget', 'Riwayat transaksi'],
        };
      }

      // ── DEFAULT FALLBACK JUJUR ─────────────────────────────────────────
      return {
        'tipe': 'jawaban',
        'pesan': 'Maaf, saya belum memahami pesan tersebut.\n\nSaya asisten keuangan MengFin dan bisa membantu:\n• Mencatat transaksi (*"beli makan 30rb"*)\n• Cek saldo dan rekening (*"berapa saldo saya?"*)\n• Analisis & ringkasan (*"analisis keuanganku"*)\n• Tips penghematan (*"tips hemat"*)\n• Panduan fitur aplikasi (*"cara scan struk"*)\n\nApa yang ingin kamu lakukan?',
        'saran': ['Berapa saldo saya?', 'Gimana kondisi keuanganku?', 'Tips hemat bulan ini', 'Beli kopi 25rb'],
      };
    } catch (_) {
      return {
        'tipe': 'jawaban',
        'pesan': '👋 Halo! Saya **MengFin AI** siap membantu pencatatan dan analisis keuanganmu. Ketik pertanyaan seperti *"berapa saldo saya?"* atau *"beli kopi 25rb"*.',
        'saran': ['Berapa saldo saya?', 'Tips hemat bulan ini'],
      };
    }
  }

  static String? _detectCategoryIntent(String lower) {
    if (RegExp(r'\b(makan|minum|kopi|coffee|cafe|kafe|restoran|resto|warung|mie|nasi|ayam|bakso|jajan|snack|kuliner)\b').hasMatch(lower)) {
      return 'Makan & Minum';
    }
    if (RegExp(r'\b(bensin|bbm|pertalite|pertamax|solar|parkir|tol|ojol|gojek|grab|maxim|angkot|bus|kereta|krl|mrt|transportasi|transport)\b').hasMatch(lower)) {
      return 'Transportasi';
    }
    if (RegExp(r'\b(belanja|supermarket|minimarket|indomaret|alfamart|shopee|tokopedia|lazada|mall|olshop)\b').hasMatch(lower)) {
      return 'Belanja';
    }
    if (RegExp(r'\b(listrik|pln|pdam|air|pulsa|kuota|paket data|wifi|indihome|tagihan|bpjs|iuran)\b').hasMatch(lower)) {
      return 'Tagihan';
    }
    if (RegExp(r'\b(obat|apotek|dokter|klinik|rs|rumah sakit|vitamin|kesehatan|medis)\b').hasMatch(lower)) {
      return 'Kesehatan';
    }
    if (RegExp(r'\b(nonton|bioskop|cinema|game|steam|netflix|spotify|hiburan|wisata|rekreasi|jalan-jalan)\b').hasMatch(lower)) {
      return 'Hiburan';
    }
    if (RegExp(r'\b(baju|celana|sepatu|tas|kaos|jaket|pakaian|fashion)\b').hasMatch(lower)) {
      return 'Pakaian';
    }
    if (RegExp(r'\b(buku|kursus|kuliah|sekolah|spp|les|pendidikan|seminar)\b').hasMatch(lower)) {
      return 'Pendidikan';
    }
    return null;
  }

  static bool _isTransactionText(String t) {
    if (t.isEmpty || t.length > 85) return false;

    // Jika mengandung kata tanya / konsultasi / evaluasi, JANGAN anggap sebagai perintah input transaksi
    final isQueryOrAdvice = RegExp(
      r'(\?|\b(apakah|gimana|bagaimana|kenapa|mengapa|berapa|menurutmu|menurut anda|menurut kamu|apakah wajar|apakah bijak|apakah boros|apakah aman|apakah cukup|apakah bisa|tolong jelaskan|jelaskan|hitung|hitungkan|hitungin|konsultasi|saran|tips|tanya|kemarin|tadi|minggu lalu|bulan lalu|kalau|jika|apabila|sebaiknya|harus|perlukah|layak|apa itu|maksudnya|definisi)\b)',
      caseSensitive: false,
    ).hasMatch(t);
    if (isQueryOrAdvice) return false;

    final keywords = ['beli', 'bayar', 'makan', 'minum', 'jajan', 'kopi', 'transfer', 'kirim', 'top up', 'topup', 'belanja', 'gajian', 'gaji', 'bonus', 'pesan', 'order', 'parkir', 'bensin', 'tarik', 'setor', 'sewa', 'tagihan', 'listrik', 'pulsa'];
    final hasKeyword = keywords.any((k) => RegExp('\\b$k\\b', caseSensitive: false).hasMatch(t));
    final hasNumber = RegExp(r'\d+').hasMatch(t) || RegExp(r'\b(ribu|juta|jt|rb|k)\b', caseSensitive: false).hasMatch(t);
    return hasKeyword && hasNumber;
  }

  static Map<String, dynamic>? _fastParseTransaksiLocal(String teks) {
    final lower = teks.toLowerCase();

    // 1. Metode
    String metode = 'tunai';
    if (RegExp(r'\b(transfer|trf|tf|bca|mandiri|bri|bni|jago)\b').hasMatch(lower)) {
      metode = 'transfer';
    } else if (RegExp(r'\b(qris|qr)\b').hasMatch(lower)) {
      metode = 'qris';
    } else if (RegExp(r'\b(debit|kredit|cc)\b').hasMatch(lower)) {
      metode = 'debit';
    }

    // 2. Nominal
    double nominal = 0;
    final numMultiplierMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*(ribu|juta|jt|rb|k)\b').firstMatch(lower);
    final plainNumberMatch = RegExp(r'(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d{4,9})\b').firstMatch(lower);

    if (numMultiplierMatch != null) {
      double rawNum = double.tryParse(numMultiplierMatch.group(1)!.replaceAll(',', '.')) ?? 0;
      final unit = numMultiplierMatch.group(2)!.toLowerCase();
      if (unit == 'juta' || unit == 'jt') {
        rawNum *= 1000000;
      } else {
        rawNum *= 1000;
      }
      nominal = rawNum;
    } else if (plainNumberMatch != null) {
      final rawDigits = plainNumberMatch.group(1)!.replaceAll('.', '');
      nominal = double.tryParse(rawDigits) ?? 0;
    }

    if (nominal <= 0) return null;

    // 3. Jenis
    final isPemasukan = RegExp(r'\b(gajian|gaji|dapat transfer|terima|bonus|pemasukan|omset)\b').hasMatch(lower);
    final jenis = isPemasukan ? 'pemasukan' : 'pengeluaran';

    // 4. Kategori
    String kategori = 'Lainnya';
    if (isPemasukan) {
      if (RegExp(r'\b(gaji|gajian)\b').hasMatch(lower)) kategori = 'Gaji';
      else if (RegExp(r'\b(bonus|thr|hadiah)\b').hasMatch(lower)) kategori = 'Bonus';
      else kategori = 'Transfer';
    } else {
      if (RegExp(r'\b(makan|minum|kopi|coffee|cafe|kafe|restoran|resto|warung|mie|nasi|ayam|bakso|jajan|snack|roti)\b').hasMatch(lower)) {
        kategori = 'Makan & Minum';
      } else if (RegExp(r'\b(bensin|bbm|pertalite|pertamax|parkir|tol|ojol|gojek|grab|maxim|angkot|bus|kereta)\b').hasMatch(lower)) {
        kategori = 'Transportasi';
      } else if (RegExp(r'\b(belanja|supermarket|minimarket|indomaret|alfamart|shopee|tokopedia|mall)\b').hasMatch(lower)) {
        kategori = 'Belanja';
      } else if (RegExp(r'\b(listrik|pln|pdam|air|pulsa|kuota|paket data|wifi|tagihan)\b').hasMatch(lower)) {
        kategori = 'Tagihan';
      } else if (RegExp(r'\b(obat|apotek|dokter|klinik|rs|rumah sakit|vitamin)\b').hasMatch(lower)) {
        kategori = 'Kesehatan';
      } else if (RegExp(r'\b(nonton|bioskop|cinema|game|steam|netflix|spotify|hiburan)\b').hasMatch(lower)) {
        kategori = 'Hiburan';
      }
    }

    // 5. Deskripsi
    String deskripsi = teks
        .replaceAll(RegExp(r'^(tolong|bantu|catat|masukkan|input|tambahkan)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(pakai|pake|via|lewat)\s+(tunai|cash|transfer|tf|qris|debit|kredit|gopay|ovo|dana)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'(\d+(?:[.,]\d+)?)\s*(ribu|juta|jt|rb|k)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?:rp\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d{4,9})\b', caseSensitive: false), '')
        .trim();

    deskripsi = deskripsi.replaceAll(RegExp(r'^(beli|bayar|makan|minum|jajan|order|pesan|topup|top up)\s+', caseSensitive: false), '').trim();
    if (deskripsi.isEmpty || deskripsi.length < 2) {
      deskripsi = kategori == 'Lainnya' ? (jenis == 'pemasukan' ? 'Pemasukan' : 'Pengeluaran') : kategori;
    } else {
      deskripsi = deskripsi[0].toUpperCase() + deskripsi.substring(1);
    }

    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return {
      'jenis': jenis,
      'nominal': nominal,
      'kategori': kategori,
      'deskripsi': deskripsi,
      'metode_pembayaran': metode,
      'tanggal': today,
    };
  }

  static Future<void> konfirmasiTransaksi(Map<String, dynamic> body) async {
    // Gunakan createTransaksi agar tersimpan di database lokal & cloud secara terpadu
    await createTransaksi(body);
  }

  // ── Scan struk ─────────────────────────────────────────────────────────────
  /// Kirim gambar struk (base64) ke backend, dapat data transaksi terstruktur.
  static Future<Map<String, dynamic>> scanStruk(
    String imageBase64, String mimeType,
  ) async {
    final res = await _post('/scan', {
      'imageBase64': imageBase64,
      'mimeType': mimeType,
    }, timeout: const Duration(seconds: 60));
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  /// Kirim gambar bukti transfer / screenshot mutasi (base64) ke backend.
  static Future<List<Map<String, dynamic>>> scanMutasi(
    String imageBase64, String mimeType,
  ) async {
    final res = await _post('/scan/mutasi', {
      'imageBase64': imageBase64,
      'mimeType': mimeType,
    }, timeout: const Duration(seconds: 60));
    final list = (res['data'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? [];
    return list;
  }

  /// Kirim PDF e-statement (base64) ke backend untuk diekstrak jadi daftar transaksi.
  static Future<List<Map<String, dynamic>>> importEStatement(String pdfBase64) async {
    final res = await _post('/scan/estatement', {
      'pdfBase64': pdfBase64,
      'mimeType': 'application/pdf',
    }, timeout: const Duration(seconds: 60));
    final list = (res['data'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? [];
    return list;
  }

  // ── Laporan: narasi AI ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getNarasiLaporan(
    String bulan, {
    List<Transaksi>? localTxs,
  }) async {
    if (_online) {
      try {
        final res = await _get('/laporan/narasi?bulan=$bulan');
        final data = Map<String, dynamic>.from(res['data'] as Map);
        if (data['narasi'] != null &&
            data['narasi'].toString().isNotEmpty &&
            data['kosong'] != true) {
          return data;
        }
      } catch (_) {}
    }

    // Fallback cerdas berbasis data transaksi aktual
    final txs = localTxs ?? [];
    if (txs.isEmpty) {
      return {
        'narasi': 'Belum ada transaksi tercatat di periode $bulan. Catat transaksi baru untuk melihat ringkasan dan analisis pengeluaran.',
        'kosong': true,
      };
    }

    final totalMasuk = txs
        .where((t) => t.jenis == 'pemasukan')
        .fold(0.0, (s, t) => s + t.nominal);
    final totalKeluar = txs
        .where((t) => t.jenis == 'pengeluaran')
        .fold(0.0, (s, t) => s + t.nominal);
    final net = totalMasuk - totalKeluar;

    final katMap = <String, double>{};
    for (final t in txs.where((t) => t.jenis == 'pengeluaran')) {
      katMap[t.kategori] = (katMap[t.kategori] ?? 0) + t.nominal;
    }
    final topKats = katMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sb = StringBuffer();
    sb.writeln('**Ringkasan**');
    if (totalMasuk > 0 && net >= 0) {
      final tabungPersen = (net / totalMasuk * 100).toStringAsFixed(0);
      sb.writeln('Kondisi keuangan periode ini sehat dengan arus kas surplus **Rp ${_formatRp(net)}** (rasio tabungan **$tabungPersen%**). Total pemasukan Rp ${_formatRp(totalMasuk)} dan total pengeluaran Rp ${_formatRp(totalKeluar)}.');
    } else if (net < 0) {
      sb.writeln('Arus kas periode ini mengalami defisit sebesar **-Rp ${_formatRp(net.abs())}**. Pengeluaran (Rp ${_formatRp(totalKeluar)}) melampaui pemasukan (Rp ${_formatRp(totalMasuk)}).');
    } else {
      sb.writeln('Total pengeluaran tercatat sebesar **Rp ${_formatRp(totalKeluar)}** dari ${txs.length} transaksi.');
    }

    sb.writeln('\n**Yang Menonjol**');
    if (topKats.isNotEmpty) {
      final top1 = topKats.first;
      final p1 = totalKeluar > 0 ? (top1.value / totalKeluar * 100).toStringAsFixed(0) : '0';
      sb.writeln('• Pengeluaran terbesar pada kategori **${top1.key}** sebesar **Rp ${_formatRp(top1.value)}** ($p1% dari total pengeluaran).');
      if (topKats.length > 1) {
        final top2 = topKats[1];
        final p2 = totalKeluar > 0 ? (top2.value / totalKeluar * 100).toStringAsFixed(0) : '0';
        sb.writeln('• Kategori terbesar kedua adalah **${top2.key}** sebesar **Rp ${_formatRp(top2.value)}** ($p2%).');
      }
    }
    sb.writeln('• Tercatat total **${txs.length} transaksi** pada periode ini.');

    sb.writeln('\n**Saran**');
    if (net < 0) {
      sb.writeln('1. Kurangi pos pengeluaran sekunder pada kategori ${topKats.isNotEmpty ? topKats.first.key : 'terbesar'} untuk menyeimbangkan arus kas.');
      sb.writeln('2. Buat anggaran ketat untuk periode berikutnya agar tidak defisit.');
    } else {
      sb.writeln('1. Sisihkan sebagian surplus dana (minimal 20%) ke pos tabungan atau impian (goals).');
      sb.writeln('2. Pertahankan kebiasaan mencatat transaksi secara konsisten.');
    }

    return {
      'narasi': sb.toString().trim(),
      'kosong': false,
    };
  }

  static String _formatRp(double amount) {
    final i = amount.round();
    final s = i.toString();
    final buf = StringBuffer();
    var count = 0;
    for (var j = s.length - 1; j >= 0; j--) {
      buf.write(s[j]);
      count++;
      if (count % 3 == 0 && j > 0) buf.write('.');
    }
    return buf.toString().split('').reversed.join();
  }

  // ── Update checker (via backend, terintegrasi GitHub) ──────────────────────
  // ── Trigger sync ───────────────────────────────────────────────────────────
  static Future<void> triggerSync() => SyncService.instance.syncToServer();

  // ── Helper: deteksi perubahan daftar akun ──────────────────────────────────
  /// Bandingkan dua daftar akun, return true jika ada perubahan signifikan:
  /// - Jumlah item berbeda
  /// - Saldo berubah > 0.01
  /// - Nama atau jenis berubah
  static bool _akunListChanged(List<Akun> oldList, List<Akun> newList) {
    final oldMap = {for (var a in oldList) a.id ?? '' : a};
    final newMap = {for (var a in newList) a.id ?? '' : a};
    
    // Cek perubahan jumlah item
    if (oldMap.length != newMap.length) {
      return true;
    }
    
    // Cek setiap item untuk perubahan
    for (final id in oldMap.keys) {
      if (!newMap.containsKey(id)) {
        return true;
      }
      final oldAkun = oldMap[id]!;
      final newAkun = newMap[id]!;
      if ((oldAkun.saldo - newAkun.saldo).abs() > 0.01 ||
          oldAkun.nama != newAkun.nama ||
          oldAkun.jenis != newAkun.jenis) {
        return true;
      }
    }
    
    return false;
  }
}
