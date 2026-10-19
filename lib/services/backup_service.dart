import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_colors.dart';
import 'app_events.dart';
import 'app_prefs.dart';
import 'local_db.dart';

class BackupService {
  static const String backupFormat = 'mengfin-backup';
  static const int currentVersion = 1;
  static const List<String> supportedTables = [
    'akun',
    'anggaran',
    'goals',
    'notif_draft',
    'transaksi',
  ];

  /// Membuat payload Map JSON terstruktur berversi.
  static Map<String, dynamic> createBackupPayload(
    Map<String, List<Map<String, dynamic>>> tablesData, {
    String appVersion = '1.0.0',
  }) {
    return {
      'format': backupFormat,
      'version': currentVersion,
      'appVersion': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tablesData,
    };
  }

  /// Membaca seluruh data dari 5 tabel SQLite lokal.
  static Future<Map<String, dynamic>> generateFullBackup() async {
    final db = await LocalDb.db;
    final tablesData = <String, List<Map<String, dynamic>>>{};

    for (final table in supportedTables) {
      try {
        final rows = await db.query(table);
        tablesData[table] = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      } catch (_) {
        tablesData[table] = [];
      }
    }

    return createBackupPayload(tablesData);
  }

  /// Folder privat penyimpanan salinan cadangan (terdeteksi otomatis saat restore).
  static Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/mengfin_backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Simpan salinan cadangan + batasi 10 berkas terbaru.
  static Future<void> saveLocalCopy(String jsonStr, String stamp) async {
    try {
      final dir = await _backupDir();
      final file = File('${dir.path}/mengfin-backup-$stamp.json');
      await file.writeAsString(jsonStr, encoding: utf8);
      final files = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path)); // stamp sortable: terbaru dulu
      for (final old in files.skip(10)) {
        try {
          await old.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Daftar berkas cadangan lokal, terbaru dulu. [] bila tidak ada / gagal.
  static Future<List<File>> listLocalBackups() async {
    try {
      final dir = await _backupDir();
      if (!await dir.exists()) return [];
      final files = (await dir.list().toList())
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (_) {
      return [];
    }
  }

  /// Ekspor seluruh database ke file JSON dan panggil share sheet sistem.
  static Future<void> exportAndShare(BuildContext context) async {
    try {
      final payload = await generateFullBackup();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

      final tempDir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
      final filePath = '${tempDir.path}/mengfin-backup-$stamp.json';
      final file = File(filePath);
      await file.writeAsString(jsonStr, encoding: utf8);
      await saveLocalCopy(jsonStr, stamp);

      // Bersihkan file cadangan lama agar tidak menumpuk di temp.
      try {
        await for (final e in tempDir.list()) {
          if (e is File && e.path.contains('mengfin-backup-') && e.path != filePath) {
            final age = DateTime.now().difference(await e.lastModified());
            if (age.inDays > 7) await e.delete();
          }
        }
      } catch (_) {}

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'mengfin-backup-$stamp.json',
          text: 'Berkas Cadangan Database MengFin ($stamp)',
        ),
      );

      // Catat waktu ekspor hanya bila user benar-benar membagikan berkas.
      if (result.status == ShareResultStatus.success) {
        final nowFormatted = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
        await AppPrefs.instance.setLastBackupTime(nowFormatted);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengekspor cadangan: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  /// Validasi berkas JSON cadangan dan ekstrak ringkasannya.
  static Map<String, dynamic> validateBackupJson(String rawJson) {
    dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (e) {
      throw const FormatException('Berkas cadangan bukan JSON yang valid.');
    }

    if (decoded is! Map<String, dynamic> && decoded is! Map) {
      throw const FormatException('Struktur berkas cadangan tidak valid (harus objek JSON).');
    }

    final map = Map<String, dynamic>.from(decoded as Map);

    if (map['format'] != backupFormat) {
      throw Exception('Format cadangan tidak dikenali (${map['format']}). Harap gunakan berkas cadangan MengFin.');
    }

    if (map['version'] != currentVersion) {
      throw Exception('Versi format cadangan (${map['version']}) tidak didukung oleh versi aplikasi ini.');
    }

    if (map['tables'] is! Map) {
      throw const FormatException('Data tabel tidak ditemukan dalam berkas cadangan.');
    }

    final rawTables = Map<String, dynamic>.from(map['tables'] as Map);
    final tables = <String, List<Map<String, dynamic>>>{};

    for (final table in supportedTables) {
      final list = rawTables[table];
      if (list is List) {
        tables[table] = list.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
      } else {
        tables[table] = [];
      }
    }

    return {
      'exportedAt': map['exportedAt']?.toString() ?? '-',
      'appVersion': map['appVersion']?.toString() ?? '-',
      'transaksiCount': tables['transaksi']?.length ?? 0,
      'akunCount': tables['akun']?.length ?? 0,
      'anggaranCount': tables['anggaran']?.length ?? 0,
      'goalsCount': tables['goals']?.length ?? 0,
      'notifDraftCount': tables['notif_draft']?.length ?? 0,
      'syncQueueCount': 0, // sync_queue tidak lagi di-backup
      'tables': tables,
    };
  }

  /// Timpa seluruh isi 5 tabel secara atomic dalam satu SQLite transaction.
  static Future<void> restoreFromJsonString(String rawJson) async {
    final validation = validateBackupJson(rawJson);
    final tables = validation['tables'] as Map<String, List<Map<String, dynamic>>>;

    final db = await LocalDb.db;
    await db.transaction((txn) async {
      // 1. Bersihkan 5 tabel
      for (final table in supportedTables) {
        try {
          await txn.delete(table);
        } catch (_) {}
      }

      // 2. Masukkan data cadangan
      for (final table in supportedTables) {
        final rows = tables[table];
        if (rows != null) {
          for (final row in rows) {
            if (row.isNotEmpty) {
              await txn.insert(
                table,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      }
    });

    // 3. Picu sinyal UI update
    AppEvents.instance.transaksiBerubah();
    AppEvents.instance.akunBerubah();
    AppEvents.instance.anggaranBerubah();
    AppEvents.instance.goalsBerubah();
    AppEvents.instance.notifDraftBerubah();
  }
}
