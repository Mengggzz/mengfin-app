import 'dart:convert';
import 'api_service.dart';
import 'app_events.dart';
import 'local_db.dart';

/// Catatan log sinkronisasi
class SyncLogEntry {
  final DateTime timestamp;
  final String title;
  final String message;
  final bool isError;
  final String type; // 'auto', 'manual', 'pull', 'push', 'info'

  const SyncLogEntry({
    required this.timestamp,
    required this.title,
    required this.message,
    this.isError = false,
    this.type = 'info',
  });
}

/// Hasil satu kali sinkronisasi.
class SyncResult {
  final int terkirim;
  final int gagal;
  final int pending;
  final bool adaGagal;
  final String? lastError;

  const SyncResult({
    this.terkirim = 0,
    this.gagal = 0,
    this.pending = 0,
    this.adaGagal = false,
    this.lastError,
  });
}

class SyncService {
  SyncService._() {
    // Catatan log awal sinkronisasi otomatis
    addLog(
      'Sinkronisasi Otomatis Aktif',
      'Data dompet, transaksi, dan anggaran otomatis diselaraskan ke database cloud saat online.',
      type: 'auto',
    );
  }
  static final SyncService instance = SyncService._();

  bool _syncing = false;
  DateTime? _lastSyncTime;
  String? _lastError;
  final List<SyncLogEntry> _logs = [];

  bool get isSyncing => _syncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  List<SyncLogEntry> get logs => List.unmodifiable(_logs);

  void addLog(String title, String message, {bool isError = false, String type = 'info'}) {
    final entry = SyncLogEntry(
      timestamp: DateTime.now(),
      title: title,
      message: message,
      isError: isError,
      type: type,
    );
    _logs.insert(0, entry);
    if (_logs.length > 100) {
      _logs.removeRange(100, _logs.length);
    }
  }

  void clearLogs() {
    _logs.clear();
    addLog(
      'Log Dibersihkan',
      'Riwayat log sinkronisasi telah direset.',
      type: 'info',
    );
  }

  /// Pull data terbaru dari server ke SQLite lokal
  Future<void> pullFromServer() async {
    try {
      addLog('Menarik Data Cloud', 'Memperbarui transaksi, anggaran, dan dompet lokal...', type: 'pull');
      
      // Pull transaksi
      final txList = await ApiService.getTransaksiFromServer(limit: 200);
      await LocalDb.upsertTransaksiBatch(txList, synced: true);

      // Pull goals
      final goalList = await ApiService.getGoalsFromServer();
      await LocalDb.upsertGoalBatch(goalList, synced: true);

      // Pull anggaran bulan ini + 3 bulan terakhir
      final now = DateTime.now();
      for (int i = 0; i < 3; i++) {
        final dt = DateTime(now.year, now.month - i);
        final periode = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        final angList = await ApiService.getAnggaranFromServer(periode);
        await LocalDb.upsertAnggaranBatch(angList, synced: true);
      }

      // Pull akun (dompet) — saldo di server berubah oleh transaksi yang
      // baru saja disinkronkan; tanpa ini menu Saldo tetap pakai saldo lama.
      await ApiService.pullAkun();
      await LocalDb.reconcileAkunSaldo();
      
      AppEvents.instance.transaksiBerubah();
      AppEvents.instance.anggaranBerubah();
      AppEvents.instance.goalsBerubah();
      AppEvents.instance.akunBerubah();

      // Cek kesehatan sync (Task 4d): verifikasi integritas dokumen lokal vs server
      try {
        final serverTxCount = txList.length;
        final d = await LocalDb.db;
        final localTxRows = await d.rawQuery('SELECT COUNT(*) as c FROM transaksi');
        final localTxCount = (localTxRows.first['c'] as int?) ?? 0;

        final serverAkunList = await ApiService.getAkunList();
        final localAkunList = await LocalDb.getAkunList();

        if (localTxCount != serverTxCount || localAkunList.length != serverAkunList.length) {
          await LocalDb.reconcileAkunSaldo();
          addLog(
            'Cek Kesehatan Sync',
            'Selisih terdeteksi (Tx: lokal $localTxCount vs server $serverTxCount, Akun: lokal ${localAkunList.length} vs server ${serverAkunList.length}) → Reconcile otomatis dijalankan.',
            type: 'pull',
          );
        }
      } catch (_) {}

      addLog('Data Cloud Selaras', 'Transaksi (${txList.length}), Dompet, dan Anggaran up-to-date.', type: 'pull');
    } catch (e) {
      addLog('Gagal Menarik Data', 'Koneksi terputus / server offline: $e', isError: true, type: 'pull');
    }
  }

  /// Pemicu sinkronisasi manual lengkap dari UI
  Future<SyncResult> triggerManualSync() async {
    addLog('Sinkronisasi Manual Dimulai', 'Memeriksa antrean perubahan offline & server...', type: 'manual');
    final res = await syncToServer(force: true);
    await pullFromServer();
    final remainingPending = await LocalDb.getPendingCount();
    if (res.adaGagal) {
      final errMsg = res.lastError ?? _lastError ?? 'Kendala pengiriman data';
      addLog(
        'Sinkronisasi Parsial',
        'Berhasil: ${res.terkirim}\nGagal: ${res.gagal}\nPending: $remainingPending\n\nError terakhir:\n$errMsg',
        isError: true,
        type: 'manual',
      );
    } else {
      addLog(
        'Sinkronisasi Selesai',
        'Semua data berhasil diselaraskan ke database cloud (${res.terkirim} perubahan terkirim).',
        type: 'manual',
      );
    }
    return res;
  }

  /// Kirim semua item dari sync_queue ke server.
  ///
  /// [kirim] opsional untuk mengganti jalur pengiriman (dipakai tes).
  /// Produksi memakai ApiService raw.
  Future<SyncResult> syncToServer({
    Future<bool> Function(Map<String, dynamic> item)? kirim,
    bool force = false,
  }) async {
    if (_syncing) return const SyncResult();
    
    // Cegah sync terlalu sering (minimal 10 detik antar sync)
    // Kecuali saat tes (kirim != null) atau manual (force == true)
    if (kirim == null && !force) {
      final now = DateTime.now();
      if (_lastSyncTime != null) {
        final diff = now.difference(_lastSyncTime!);
        if (diff.inSeconds < 10) {
          final pending = await LocalDb.getPendingCount();
          return SyncResult(pending: pending);
        }
      }
    }
    
    _syncing = true;
    _lastError = null;

    var terkirim = 0;
    var gagal = 0;

    try {
      final queue = await LocalDb.getQueue();
      if (queue.isNotEmpty) {
        addLog('Mengunggah Perubahan', 'Mengirim ${queue.length} antrean data offline ke database...', type: 'push');
      }

      for (final item in queue) {
        final id = item['id'] as int;
        final method = item['method'] as String;
        final path = item['path'] as String;
        final bodyStr = item['body'] as String? ?? '{}';
        final localId = item['local_id'] as String? ?? '';
        final tableName = item['table_name'] as String;
        final retryCount = (item['retry_count'] as int?) ?? 0;
        final lastAttemptStr = item['last_attempt'] as String?;

        // ── Exponential Backoff ──────────────────────────────────
        if (kirim == null && !force && retryCount > 0 && lastAttemptStr != null && lastAttemptStr.isNotEmpty) {
          final lastAttempt = DateTime.tryParse(lastAttemptStr);
          if (lastAttempt != null) {
            final waitSeconds = (1 << retryCount.clamp(0, 8)) * 2;
            if (DateTime.now().difference(lastAttempt).inSeconds < waitSeconds) {
              gagal++;
              continue; // Masih dalam masa jeda backoff
            }
          }
        }

        final pathSegments = path.split('/').where((s) => s.isNotEmpty).toList();
        final pathId = pathSegments.length >= 2 ? pathSegments[1].split('?').first : '';
        final hasPathId = pathId.isNotEmpty;

        try {
          final body = jsonDecode(bodyStr) as Map<String, dynamic>;

          if (kirim != null) {
            final ok = await kirim({...item, 'body': body});
            if (!ok) throw Exception('Pengiriman gagal');
          } else if (method == 'POST' && tableName == 'transaksi') {
            // Resolusi akun_id jika masih berupa ID lokal atau belum terisi
            if (body['akun_id'] == null || body['akun_id'] == 'null' || body['akun_id'].toString().isEmpty) {
              final akuns = await LocalDb.getAkunList();
              if (akuns.isNotEmpty) {
                body['akun_id'] = akuns.first.id;
              }
            } else {
              final aid = body['akun_id'].toString().trim();
              if (aid.startsWith('akun_') || aid == 'null' || aid == 'undefined' || aid.isEmpty) {
                final serverAkunId = await LocalDb.getServerIdForAkun(aid);
                body['akun_id'] = (serverAkunId != null && serverAkunId.isNotEmpty) ? serverAkunId : null;
              }
            }
            if (localId.isNotEmpty) body['local_id'] = localId;

            final result = await ApiService.createTransaksiRaw(body);
            final serverId = result['data']?['id']?.toString() ?? result['data']?['_id']?.toString();
            if (serverId != null && serverId.isNotEmpty) {
              await LocalDb.replaceTransaksiLocalToServer(localId, serverId);
            }
          } else if (method == 'PUT' && tableName == 'transaksi') {
            String actualId = pathId;
            if (pathId.startsWith('tx_') || pathId.startsWith('upd_tx_')) {
              final clean = pathId.replaceFirst('upd_tx_', '');
              final resolved = await LocalDb.getServerIdForTransaksi(clean);
              if (resolved != null && resolved.isNotEmpty) {
                actualId = resolved;
              } else {
                // POST transaksi belum tersinkron ke server, tunda PUT ke siklus sync berikutnya
                continue;
              }
            }
            if (hasPathId) await ApiService.updateTransaksiRaw(actualId, body);
          } else if (method == 'DELETE' && tableName == 'transaksi') {
            String actualId = pathId;
            if (pathId.startsWith('tx_') || pathId.startsWith('del_tx_')) {
              final clean = pathId.replaceFirst('del_tx_', '');
              final resolved = await LocalDb.getServerIdForTransaksi(clean);
              if (resolved != null && resolved.isNotEmpty) {
                actualId = resolved;
              } else {
                // Transaksi lokal yang belum pernah masuk cloud dan sudah dihapus lokal
                await LocalDb.removeFromQueue(id);
                terkirim++;
                continue;
              }
            }
            if (hasPathId) await ApiService.deleteTransaksiRaw(actualId);
          } else if (method == 'POST' && tableName == 'anggaran') {
            final result = await ApiService.createAnggaranRaw(
                body['kategori'], (body['batas'] as num).toDouble(), body['periode']);
            final serverId = result['data']?['id']?.toString() ?? result['data']?['_id']?.toString();
            if (serverId != null && serverId.isNotEmpty) {
              await LocalDb.replaceAnggaranLocalToServer(localId, serverId);
            }
          } else if (method == 'PUT' && tableName == 'anggaran') {
            if (hasPathId) {
              await ApiService.updateAnggaranRaw(pathId, (body['batas'] as num).toDouble());
            }
          } else if (method == 'DELETE' && tableName == 'anggaran') {
            if (hasPathId) await ApiService.deleteAnggaranRaw(pathId);
          } else if (method == 'POST' && tableName == 'goals') {
            final result = await ApiService.createGoalRaw(body);
            final serverId = result['data']?['id']?.toString() ?? result['data']?['_id']?.toString();
            if (serverId != null && serverId.isNotEmpty) {
              await LocalDb.replaceGoalLocalToServer(localId, serverId);
            }
          } else if (method == 'PUT' && tableName == 'goals') {
            if (hasPathId) {
              await ApiService.updateProgresRaw(pathId, (body['tambah'] as num).toDouble());
            }
          } else if (method == 'DELETE' && tableName == 'goals') {
            if (hasPathId) await ApiService.deleteGoalRaw(pathId);
          } else if (method == 'POST' && tableName == 'akun') {
            if (localId.isNotEmpty) body['local_id'] = localId;
            if (body.containsKey('jenis')) {
              body['jenis'] = ApiService.normalizeJenisForServer(body['jenis']?.toString());
            }
            final result = await ApiService.createAkunRaw(body);
            final serverId = result['data']?['id']?.toString() ?? result['data']?['_id']?.toString();
            if (serverId != null && serverId.isNotEmpty) {
              await LocalDb.replaceAkunLocalToServer(localId, serverId);
            }
          } else if (method == 'PUT' && tableName == 'akun') {
            String actualId = pathId;
            if (pathId.startsWith('akun_')) {
              final resolved = await LocalDb.getServerIdForAkun(pathId);
              if (resolved != null && resolved.isNotEmpty) {
                actualId = resolved;
              } else {
                // POST akun belum tersinkron, tunda PUT ke siklus sync berikutnya
                continue;
              }
            }
            if (hasPathId) {
              await ApiService.updateAkunSaldoRaw(actualId, (body['saldo'] as num).toDouble());
            }
          } else if (method == 'DELETE' && tableName == 'akun') {
            String actualId = pathId;
            if (pathId.startsWith('akun_')) {
              final resolved = await LocalDb.getServerIdForAkun(pathId);
              if (resolved != null && resolved.isNotEmpty) {
                actualId = resolved;
              } else {
                await LocalDb.removeFromQueue(id);
                terkirim++;
                continue;
              }
            }
            if (hasPathId) await ApiService.deleteAkunRaw(actualId);
          } else if (method == 'DONE') {
            // penanda lokal
          }

          // Hapus dari antrean HANYA setelah operasi benar-benar berhasil.
          await LocalDb.removeFromQueue(id);
          terkirim++;
        } catch (e) {
          gagal++;
          final rawMsg = e.toString().replaceFirst('Exception: ', '');
          _lastError = rawMsg;
          final newRetry = retryCount + 1;
          final isPermanent = rawMsg.contains('400') || rawMsg.contains('404') || rawMsg.contains('validation') || rawMsg.contains('validasi');
          final isPermanentFailed = isPermanent || newRetry >= 5;
          
          await LocalDb.updateQueueItem(
            id,
            retryCount: newRetry,
            lastError: rawMsg,
            lastAttempt: DateTime.now().toIso8601String(),
            status: isPermanentFailed ? 'permanent_failed' : 'failed',
          );

          addLog(
            'Gagal [$tableName $method]',
            'ID: $localId (Percobaan #$newRetry)\nError: $rawMsg',
            isError: true,
            type: 'push',
          );
          continue;
        }
      }

      // Setelah sync berhasil, pull data terbaru
      if (gagal == 0) await pullFromServer();
    } finally {
      _syncing = false;
      if (terkirim > 0 || gagal > 0 || force) {
        _lastSyncTime = DateTime.now();
      }
    }

    final pending = await LocalDb.getPendingCount();
    return SyncResult(
      terkirim: terkirim,
      gagal: gagal,
      pending: pending,
      adaGagal: gagal > 0,
      lastError: _lastError,
    );
  }
}
