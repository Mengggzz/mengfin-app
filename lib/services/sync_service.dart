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
  final bool adaGagal;

  const SyncResult({this.terkirim = 0, this.gagal = 0, this.adaGagal = false});
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
  final List<SyncLogEntry> _logs = [];

  bool get isSyncing => _syncing;
  DateTime? get lastSyncTime => _lastSyncTime;
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
      // baru saja disinkronkan; tanpa ini menu Kazz tetap pakai saldo lama.
      await ApiService.pullAkun();
      
      AppEvents.instance.transaksiBerubah();
      AppEvents.instance.anggaranBerubah();
      AppEvents.instance.goalsBerubah();
      AppEvents.instance.akunBerubah();

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
    if (res.adaGagal) {
      addLog(
        'Sinkronisasi Parsial',
        'Terkirim: ${res.terkirim}, Gagal: ${res.gagal}. Item gagal akan dicoba lagi otomatis.',
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
  /// Produksi memakai [_kirimKeServer].
  ///
  /// PENTING: id server sekarang String (ObjectId MongoDB), bukan int.
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
          return const SyncResult();
        }
      }
    }
    
    _syncing = true;

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

        // Ambil id server dari segmen ke-2 path (String/ObjectId).
        // Contoh: '/transaksi/abc123' → 'abc123'
        //         '/goals/abc123/progres' → 'abc123' (bukan 'progres')
        final pathSegments = path.split('/').where((s) => s.isNotEmpty).toList();
        // pathId = segmen setelah nama tabel (index 1), bukan segmen terakhir
        final pathId = pathSegments.length >= 2 ? pathSegments[1].split('?').first : '';
        final hasPathId = pathId.isNotEmpty;

        try {
          final body = jsonDecode(bodyStr) as Map<String, dynamic>;

          if (kirim != null) {
            final ok = await kirim({...item, 'body': body});
            if (!ok) throw Exception('gagal');
          } else if (method == 'POST' && tableName == 'transaksi') {
            final result = await ApiService.createTransaksiRaw(body);
            final serverId = result['data']?['id']?.toString();
            if (serverId != null && serverId.isNotEmpty) {
              await LocalDb.replaceTransaksiLocalToServer(localId, serverId);
            }
          } else if (method == 'PUT' && tableName == 'transaksi') {
            if (hasPathId) await ApiService.updateTransaksiRaw(pathId, body);
          } else if (method == 'DELETE' && tableName == 'transaksi') {
            if (hasPathId) await ApiService.deleteTransaksiRaw(pathId);
          } else if (method == 'POST' && tableName == 'anggaran') {
            final result = await ApiService.createAnggaranRaw(
                body['kategori'], (body['batas'] as num).toDouble(), body['periode']);
            final serverId = result['data']?['id']?.toString();
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
            final serverId = result['data']?['id']?.toString();
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
            final result = await ApiService.createAkunRaw(body);
            final serverId = result['data']?['id']?.toString();
            if (serverId != null && serverId.isNotEmpty) {
              await LocalDb.replaceAkunLocalToServer(localId, serverId);
            }
          } else if (method == 'PUT' && tableName == 'akun') {
            if (hasPathId) {
              await ApiService.updateAkunSaldoRaw(pathId, (body['saldo'] as num).toDouble());
            }
          } else if (method == 'DELETE' && tableName == 'akun') {
            if (hasPathId) await ApiService.deleteAkunRaw(pathId);
          } else if (method == 'DONE') {
            // penanda lokal saja
          }

          // Hapus dari antrean HANYA setelah operasi benar-benar berhasil.
          await LocalDb.removeFromQueue(id);
          terkirim++;
        } catch (_) {
          gagal++;
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

    return SyncResult(terkirim: terkirim, gagal: gagal, adaGagal: gagal > 0);
  }
}
