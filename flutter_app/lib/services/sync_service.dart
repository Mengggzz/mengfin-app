import 'dart:convert';
import 'api_service.dart';
import 'local_db.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _syncing = false;

  /// Pull data terbaru dari server ke SQLite lokal
  Future<void> pullFromServer() async {
    try {
      // Pull transaksi
      final txList = await ApiService.getTransaksiFromServer(limit: 200);
      for (final tx in txList) {
        await LocalDb.upsertTransaksi(tx, synced: true);
      }

      // Pull goals
      final goalList = await ApiService.getGoalsFromServer();
      for (final g in goalList) {
        await LocalDb.upsertGoal(g, synced: true);
      }

      // Pull anggaran bulan ini + 3 bulan terakhir
      final now = DateTime.now();
      for (int i = 0; i < 3; i++) {
        final dt = DateTime(now.year, now.month - i);
        final periode = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
        final angList = await ApiService.getAnggaranFromServer(periode);
        for (final a in angList) {
          await LocalDb.upsertAnggaran(a, synced: true);
        }
      }
    } catch (_) {
      // Abaikan error pull — data lokal tetap tersedia
    }
  }

  /// Kirim semua item dari sync_queue ke server
  Future<void> syncToServer() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final queue = await LocalDb.getQueue();
      for (final item in queue) {
        final id = item['id'] as int;
        final method = item['method'] as String;
        final path = item['path'] as String;
        final bodyStr = item['body'] as String? ?? '{}';
        final localId = item['local_id'] as String;
        final tableName = item['table_name'] as String;

        try {
          final body = jsonDecode(bodyStr) as Map<String, dynamic>;

          if (method == 'POST' && tableName == 'transaksi') {
            final result = await ApiService.createTransaksiRaw(body);
            final serverId = result['data']?['id'] as int?;
            if (serverId != null) {
              await LocalDb.replaceTransaksiLocalToServer(localId, serverId);
            }
          } else if (method == 'DELETE' && tableName == 'transaksi') {
            final txId = int.tryParse(path.split('/').last) ?? 0;
            if (txId > 0) await ApiService.deleteTransaksiRaw(txId);
          } else if (method == 'POST' && tableName == 'anggaran') {
            await ApiService.createAnggaranRaw(body['kategori'], body['batas'], body['periode']);
          } else if (method == 'PUT' && tableName == 'anggaran') {
            final angId = int.tryParse(path.split('/').last) ?? 0;
            if (angId > 0) await ApiService.updateAnggaranRaw(angId, body['batas']);
          } else if (method == 'DELETE' && tableName == 'anggaran') {
            final angId = int.tryParse(path.split('/').last) ?? 0;
            if (angId > 0) await ApiService.deleteAnggaranRaw(angId);
          } else if (method == 'POST' && tableName == 'goals') {
            await ApiService.createGoalRaw(body);
          } else if (method == 'PUT' && tableName == 'goals') {
            final goalId = int.tryParse(path.split('/').last.split('?').first) ?? 0;
            if (goalId > 0) await ApiService.updateProgresRaw(goalId, body['tambah']);
          } else if (method == 'DELETE' && tableName == 'goals') {
            final goalId = int.tryParse(path.split('/').last) ?? 0;
            if (goalId > 0) await ApiService.deleteGoalRaw(goalId);
          }

          // Hapus dari queue setelah berhasil
          await LocalDb.removeFromQueue(id);
        } catch (_) {
          // Gagal sync item ini, coba lagi nanti
          break;
        }
      }

      // Setelah sync berhasil, pull data terbaru
      await pullFromServer();
    } finally {
      _syncing = false;
    }
  }
}
