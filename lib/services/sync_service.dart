import 'dart:convert';
import 'api_service.dart';
import 'local_db.dart';

/// Hasil satu kali sinkronisasi.
class SyncResult {
  final int terkirim;
  final int gagal;
  final bool adaGagal;

  const SyncResult({this.terkirim = 0, this.gagal = 0, this.adaGagal = false});
}

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

  /// Kirim semua item dari sync_queue ke server.
  ///
  /// PENTING: id server sekarang String (ObjectId MongoDB), bukan int.
  /// Sebelumnya kode memakai `int.tryParse` sehingga id ObjectId selalu
  /// gagal di-parse → operasi UPDATE/DELETE diam-diam tidak pernah
  /// terkirim, padahal item tetap dihapus dari antrean.
  Future<SyncResult> syncToServer() async {
    if (_syncing) return const SyncResult();
    _syncing = true;

    var terkirim = 0;
    var gagal = 0;

    try {
      final queue = await LocalDb.getQueue();
      for (final item in queue) {
        final id = item['id'] as int;
        final method = item['method'] as String;
        final path = item['path'] as String;
        final bodyStr = item['body'] as String? ?? '{}';
        final localId = item['local_id'] as String? ?? '';
        final tableName = item['table_name'] as String;

        // Ambil id server dari segmen terakhir path (String/ObjectId).
        final pathId = path.split('/').last.split('?').first;
        final hasPathId = pathId.isNotEmpty && pathId != path;

        try {
          final body = jsonDecode(bodyStr) as Map<String, dynamic>;

          if (method == 'POST' && tableName == 'transaksi') {
            final result = await ApiService.createTransaksiRaw(body);
            final serverId = result['data']?['id']?.toString();
            if (serverId != null && serverId.isNotEmpty) {
              await LocalDb.replaceTransaksiLocalToServer(localId, serverId);
            }
          } else if (method == 'DELETE' && tableName == 'transaksi') {
            if (hasPathId) await ApiService.deleteTransaksiRaw(pathId);
          } else if (method == 'POST' && tableName == 'anggaran') {
            await ApiService.createAnggaranRaw(
                body['kategori'], (body['batas'] as num).toDouble(), body['periode']);
          } else if (method == 'PUT' && tableName == 'anggaran') {
            if (hasPathId) {
              await ApiService.updateAnggaranRaw(pathId, (body['batas'] as num).toDouble());
            }
          } else if (method == 'DELETE' && tableName == 'anggaran') {
            if (hasPathId) await ApiService.deleteAnggaranRaw(pathId);
          } else if (method == 'POST' && tableName == 'goals') {
            await ApiService.createGoalRaw(body);
          } else if (method == 'PUT' && tableName == 'goals') {
            if (hasPathId) {
              await ApiService.updateProgresRaw(pathId, (body['tambah'] as num).toDouble());
            }
          } else if (method == 'DELETE' && tableName == 'goals') {
            if (hasPathId) await ApiService.deleteGoalRaw(pathId);
          } else if (method == 'DONE') {
            // penanda lokal saja — tidak ada yang perlu dikirim
          }

          // Hapus dari antrean HANYA setelah operasi benar-benar berhasil.
          await LocalDb.removeFromQueue(id);
          terkirim++;
        } catch (_) {
          // Item ini gagal — pertahankan di antrean supaya dicoba lagi nanti.
          gagal++;
          // Hentikan pengiriman berikutnya agar urutan operasi tetap terjaga
          // (mis. POST harus sukses sebelum PUT/DELETE item yang sama).
          break;
        }
      }

      // Setelah sync berhasil, pull data terbaru
      if (gagal == 0) await pullFromServer();
    } finally {
      _syncing = false;
    }

    return SyncResult(terkirim: terkirim, gagal: gagal, adaGagal: gagal > 0);
  }
}
