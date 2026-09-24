import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../constants/config.dart';
import '../models/models.dart';
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
  static Future<Map<String, dynamic>> _get(String path) async {
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl$path'),
      headers: _authHeaders,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    if (res.statusCode == 401) throw Exception('unauthorized');
    throw Exception('GET $path failed: ${res.statusCode}');
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await _client.post(
      Uri.parse('$kApiBaseUrl$path'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return jsonDecode(res.body);
    if (res.statusCode == 401) throw Exception('unauthorized');
    throw Exception('POST $path failed: ${res.body}');
  }

  static Future<void> _put(String path, Map<String, dynamic> body) async {
    await _client.put(
      Uri.parse('$kApiBaseUrl$path'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );
  }

  static Future<void> _delete(String path) async {
    await _client.delete(
      Uri.parse('$kApiBaseUrl$path'),
      headers: _authHeaders,
    );
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
  static Future<List<Transaksi>> getTransaksi({
    String? jenis, int limit = 100,
  }) async {
    if (_online) {
      try {
        final txs = await getTransaksiFromServer(jenis: jenis, limit: limit);
        // Update cache lokal (mobile/desktop only)
        if (!kIsWeb) {
          for (final tx in txs) {
            await LocalDb.upsertTransaksi(tx, synced: true);
          }
        }
        return txs;
      } catch (_) {
        // Fallback ke lokal (mobile/desktop only)
      }
    }
    if (kIsWeb) return [];
    return LocalDb.getTransaksi(jenis: jenis, limit: limit);
  }

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
    // Di web: langsung kirim ke server
    if (kIsWeb) {
      final result = await createTransaksiRaw(body);
      return Transaksi.fromJson(result['data']);
    }

    final localId = 'tx_${DateTime.now().millisecondsSinceEpoch}';
    await LocalDb.insertTransaksiLocal(body, localId);

    if (_online) {
      try {
        final result = await createTransaksiRaw(body);
        final tx = Transaksi.fromJson(result['data']);
        await LocalDb.replaceTransaksiLocalToServer(localId, tx.id);
        return tx;
      } catch (_) {}
    }

    await LocalDb.enqueue(
      method: 'POST', path: '/transaksi',
      body: jsonEncode(body), localId: localId, tableName: 'transaksi',
    );

    return Transaksi(
      id: localId,
      localId: localId,
      tanggal: body['tanggal'] ?? '', jenis: body['jenis'] ?? '',
      nominal: (body['nominal'] as num? ?? 0).toDouble(),
      kategori: body['kategori'] ?? '', deskripsi: body['deskripsi'] ?? '',
      metodePembayaran: body['metode_pembayaran'] ?? 'tunai',
      synced: false,
    );
  }

  static Future<Map<String, dynamic>> createTransaksiRaw(Map<String, dynamic> body) =>
      _post('/transaksi', body);

  static Future<void> deleteTransaksi(dynamic id) async {
    if (kIsWeb) {
      if (id != null) await deleteTransaksiRaw(id);
      return;
    }
    await LocalDb.deleteTransaksi(id);
    if (_online) {
      try {
        if (id != null) await deleteTransaksiRaw(id);
        return;
      } catch (_) {}
    }
    if (id != null) {
      await LocalDb.enqueue(
        method: 'DELETE', path: '/transaksi/$id',
        body: '{}', localId: 'del_tx_$id', tableName: 'transaksi',
      );
    }
  }

  static Future<void> deleteTransaksiRaw(dynamic id) => _delete('/transaksi/$id');

  // ── Akun ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAkun() async => _get('/akun');

  static Future<List<Akun>> getAkunList() async {
    if (!_online) return [];
    final data = await _get('/akun');
    return (data['data'] as List).map((j) => Akun.fromJson(j)).toList();
  }

  // ── Anggaran (offline-aware) ───────────────────────────────────────────────
  static Future<List<Anggaran>> getAnggaran(String periode) async {
    if (_online) {
      try {
        final list = await getAnggaranFromServer(periode);
        if (!kIsWeb) {
          for (final a in list) {
            await LocalDb.upsertAnggaran(a, synced: true);
          }
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
      return;
    }
    final localId = 'ang_${DateTime.now().millisecondsSinceEpoch}';
    await LocalDb.insertAnggaranLocal(localId, kategori, batas, periode);

    if (_online) {
      try {
        await createAnggaranRaw(kategori, batas, periode);
        await LocalDb.enqueue(method: 'DONE', path: '', body: '{}', localId: localId, tableName: 'anggaran');
        return;
      } catch (_) {}
    }
    await LocalDb.enqueue(
      method: 'POST', path: '/anggaran',
      body: jsonEncode({'kategori': kategori, 'batas': batas, 'periode': periode}),
      localId: localId, tableName: 'anggaran',
    );
  }

  static Future<void> createAnggaranRaw(String kategori, double batas, String periode) =>
      _post('/anggaran', {'kategori': kategori, 'batas': batas, 'periode': periode});

  static Future<void> updateAnggaran(dynamic id, double batas) async {
    if (kIsWeb) { await updateAnggaranRaw(id, batas); return; }
    await LocalDb.updateAnggaranBatas(id, batas);
    if (_online) {
      try {
        await updateAnggaranRaw(id, batas);
        return;
      } catch (_) {}
    }
    await LocalDb.enqueue(
      method: 'PUT', path: '/anggaran/$id',
      body: jsonEncode({'batas': batas}), localId: 'upd_ang_$id', tableName: 'anggaran',
    );
  }

  static Future<void> updateAnggaranRaw(dynamic id, double batas) =>
      _put('/anggaran/$id', {'batas': batas});

  static Future<void> deleteAnggaran(dynamic id) async {
    if (kIsWeb) { await deleteAnggaranRaw(id); return; }
    await LocalDb.deleteAnggaran(id);
    if (_online) {
      try {
        await deleteAnggaranRaw(id);
        return;
      } catch (_) {}
    }
    if (id != null) {
      await LocalDb.enqueue(
        method: 'DELETE', path: '/anggaran/$id',
        body: '{}', localId: 'del_ang_$id', tableName: 'anggaran',
      );
    }
  }

  static Future<void> deleteAnggaranRaw(dynamic id) => _delete('/anggaran/$id');

  // ── Goals (offline-aware) ──────────────────────────────────────────────────
  static Future<List<Goal>> getGoals() async {
    if (_online) {
      try {
        final list = await getGoalsFromServer();
        if (!kIsWeb) {
          for (final g in list) {
            await LocalDb.upsertGoal(g, synced: true);
          }
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
    if (kIsWeb) { await createGoalRaw(body); return; }
    final localId = 'goal_${DateTime.now().millisecondsSinceEpoch}';
    await LocalDb.insertGoalLocal(localId, body);

    if (_online) {
      try {
        await createGoalRaw(body);
        return;
      } catch (_) {}
    }
    await LocalDb.enqueue(
      method: 'POST', path: '/goals',
      body: jsonEncode(body), localId: localId, tableName: 'goals',
    );
  }

  static Future<void> createGoalRaw(Map<String, dynamic> body) =>
      _post('/goals', body);

  static Future<void> updateProgres(dynamic id, double tambah) async {
    if (kIsWeb) { await updateProgresRaw(id, tambah); return; }
    await LocalDb.updateGoalProgres(id, tambah);
    if (_online) {
      try {
        await updateProgresRaw(id, tambah);
        return;
      } catch (_) {}
    }
    await LocalDb.enqueue(
      method: 'PUT', path: '/goals/$id/progres',
      body: jsonEncode({'tambah': tambah}), localId: 'upd_goal_$id', tableName: 'goals',
    );
  }

  static Future<void> updateProgresRaw(dynamic id, double tambah) =>
      _put('/goals/$id/progres', {'tambah': tambah});

  static Future<void> deleteGoal(dynamic id) async {
    if (kIsWeb) { await deleteGoalRaw(id); return; }
    await LocalDb.deleteGoal(id);
    if (_online) {
      try {
        await deleteGoalRaw(id);
        return;
      } catch (_) {}
    }
    if (id != null) {
      await LocalDb.enqueue(
        method: 'DELETE', path: '/goals/$id',
        body: '{}', localId: 'del_goal_$id', tableName: 'goals',
      );
    }
  }

  static Future<void> deleteGoalRaw(dynamic id) => _delete('/goals/$id');

  // ── AI Chat ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> chat(String pesan) async {
    return _post('/ai/chat', {'pesan': pesan});
  }

  static Future<void> konfirmasiTransaksi(Map<String, dynamic> body) async {
    await _post('/ai/konfirmasi-transaksi', body);
  }

  // ── Scan struk ─────────────────────────────────────────────────────────────
  /// Kirim gambar struk (base64) ke backend, dapat data transaksi terstruktur.
  static Future<Map<String, dynamic>> scanStruk(
    String imageBase64, String mimeType,
  ) async {
    final res = await _post('/scan', {
      'imageBase64': imageBase64,
      'mimeType': mimeType,
    });
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  // ── Laporan: narasi AI ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getNarasiLaporan(String bulan) async {
    final res = await _get('/laporan/narasi?bulan=$bulan');
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  // ── Update checker (via backend, terintegrasi GitHub) ──────────────────────
  static Future<Map<String, dynamic>> checkUpdate() async {
    if (kIsWeb) return {'has_update': false, 'unknown_current': true};
    final res = await _client.get(
      Uri.parse('$kApiBaseUrl/update/check?current=$kAppBuildTag'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw Exception('update check failed: ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Trigger sync ───────────────────────────────────────────────────────────
  static Future<void> triggerSync() => SyncService.instance.syncToServer();
}
