# MengFin Mode Lokal (Tanpa Backend) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengalihkan aplikasi MengFin menjadi aplikasi 100% lokal offline-first dengan subsistem cadangan/pemulihan (backup/restore) JSON berversi, melewati layar login, menonaktifkan sync cloud, dan mendegradasi fitur server secara anggun.

**Architecture:** Flag terpusat `kLocalMode` di `config.dart` mengendalikan seluruh jalur jaringan. Kode server diparkir menggunakan guard `kLocalMode` tanpa penghapusan kode. Layanan `BackupService` baru menangani ekspor/impor 6 tabel SQLite secara atomic dalam satu database transaction dengan integrasi `share_plus` dan `file_picker`.

**Tech Stack:** Flutter / Dart, SQLite (`sqflite`), `share_plus`, `file_picker`, `shared_preferences`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-16-mengfin-mode-lokal-design.md`

## Global Constraints
- Kode yang berhubungan dengan server TIDAK BOLEH dihapus — diparkir dengan guard `kLocalMode`.
- Build tanpa `--dart-define=API_BASE_URL` harus otomatis mengaktifkan `kLocalMode == true`.
- Tidak boleh ada request HTTP ke URL Railway yang sudah mati (`https://web-production-c21a6.up.railway.app/api`).
- Format cadangan JSON harus menggunakan format `"mengfin-backup"` dengan versi integer `1`.
- Pemulihan database (restore) wajib dijalankan di dalam satu SQLite transaction atomic (`db.transaction`).
- Keystore signing secrets di `.github/workflows/build.yml` tidak boleh diubah agar APK rilis tetap mempertahankan signature yang sama.
- Jangan melakukan `git commit` atau `git push` otomatis tanpa instruksi eksplisit dari pengguna.

## Review Focus
1. Berkas JSON cadangan tidak lengkap (kurang salah satu dari 6 tabel) -> Ditolak atau diisi list kosong dengan aman tanpa crash database.
2. Berkas JSON korup atau format acak (misal file CSV atau teks sembarang) -> Ditolak dengan pesan error validasi yang jelas, transaksi dibatalkan.
3. Transaksi pemulihan gagal di tengah proses -> SQLite me-rollback seluruh perubahan sehingga data awal tetap utuh 100%.
4. Ekspor saat database kosong (0 baris di semua tabel) -> Menghasilkan JSON cadangan valid dengan array tabel kosong `[]`, tidak melempar exception.
5. Pemanggilan fitur server saat mode lokal (misal scan mutasi atau impor PDF) -> Menampilkan pesan edukasi bahwa fitur membutuhkan server tanpa melempar crash `SocketException`.

---

### Task 1: Flag Mode Lokal di Config

**Files:**
- Modify: `lib/constants/config.dart:8-12`
- Test: `test/constants/config_test.dart`

**Interfaces:**
- Produces: `bool kLocalMode`, `String kApiBaseUrl`

- [ ] **Step 1: Tulis unit test untuk verifikasi default `kLocalMode`**

Buat file `test/constants/config_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/constants/config.dart';

void main() {
  test('kLocalMode bernilai true secara default saat API_BASE_URL tidak diset', () {
    expect(kLocalMode, isTrue);
  });

  test('kApiBaseUrl kosong saat mode lokal aktif', () {
    expect(kApiBaseUrl, isEmpty);
  });
}
```

- [ ] **Step 2: Jalankan test untuk memastikan test gagal (atau file belum ada)**

Run: `flutter test test/constants/config_test.dart`
Expected: FAIL (karena `kLocalMode` belum terdefinisi).

- [ ] **Step 3: Implementasikan `kLocalMode` di `lib/constants/config.dart`**

Ubah `lib/constants/config.dart` baris 8-12:
```dart
const String _kApiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');
const bool kLocalMode = _kApiBaseUrlOverride == '' || _kApiBaseUrlOverride == 'local';
const String kApiBaseUrl = kLocalMode
    ? ''
    : _kApiBaseUrlOverride;
```

- [ ] **Step 4: Jalankan test kembali untuk verifikasi keberhasilan**

Run: `flutter test test/constants/config_test.dart`
Expected: PASS.

- [ ] **Step 5: Review lokal**

Pastikan `git diff lib/constants/config.dart` bersih dan sesuai.

---

### Task 2: Lewati Login & Atur Profil Lokal

**Files:**
- Modify: `lib/services/auth_service.dart:37-40, 91-109`
- Modify: `lib/main.dart:101-105`
- Test: `test/services/auth_service_local_test.dart`

**Interfaces:**
- Consumes: `kLocalMode` from `lib/constants/config.dart`
- Produces: `AuthService.instance.isLoggedIn == true`, `AuthService.instance.user` profil lokal statis

- [ ] **Step 1: Tulis test untuk verifikasi AuthService pada mode lokal**

Buat file `test/services/auth_service_local_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/constants/config.dart';
import 'package:mengfin/services/auth_service.dart';

void main() {
  test('AuthService menganggap user sudah login saat kLocalMode aktif', () {
    if (kLocalMode) {
      expect(AuthService.instance.isLoggedIn, isTrue);
      expect(AuthService.instance.user?['nama'], equals('Pengguna Lokal'));
    }
  });
}
```

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan awal**

Run: `flutter test test/services/auth_service_local_test.dart`
Expected: FAIL (karena `isLoggedIn` masih memeriksa token).

- [ ] **Step 3: Modifikasi `lib/services/auth_service.dart`**

Ubah getter `isLoggedIn`, `user`, dan guard `signInWithGoogle`:
```dart
  Map<String, dynamic>? get user => kLocalMode
      ? (_user ?? const {'nama': 'Pengguna Lokal', 'email': 'lokal@mengfin.app'})
      : _user;
  bool get isLoggedIn => kLocalMode ? true : _token != null;

  Future<bool> signInWithGoogle() async {
    if (kLocalMode) return true;
    if (kIsWeb) {
      webAuth.triggerGoogleSignIn();
      return false;
    } else {
      try {
        final account = await _googleSignIn.signIn();
        if (account == null) return false;
        final auth = await account.authentication;
        if (auth.idToken == null) throw Exception('No ID token');
        return await _postToAuth({'idToken': auth.idToken!});
      } catch (e) {
        print('Mobile sign-in error: $e');
        rethrow;
      }
    }
  }
```

- [ ] **Step 4: Modifikasi `lib/main.dart`**

Di `lib/main.dart` baris 101:
```dart
initialRoute: (kLocalMode || AuthService.instance.isLoggedIn) ? '/home' : '/login',
```

- [ ] **Step 5: Jalankan test untuk verifikasi keberhasilan**

Run: `flutter test test/services/auth_service_local_test.dart`
Expected: PASS.

---

### Task 3: Nonaktifkan Sinkronisasi & Pengecekan Server

**Files:**
- Modify: `lib/services/sync_service.dart:87, 167, 194`
- Modify: `lib/services/connectivity_service.dart:38, 71-82`
- Modify: `lib/services/api_service.dart:123-168`
- Modify: `lib/main.dart:73-75, 158-169`

**Interfaces:**
- Consumes: `kLocalMode` from `lib/constants/config.dart`
- Produces: Guard no-op pada sinkronisasi cloud dan bypass ping server

- [ ] **Step 1: Pasang guard pada `lib/services/sync_service.dart`**

Di method `pullFromServer()`:
```dart
  Future<void> pullFromServer() async {
    if (kLocalMode) return;
    ...
```

Di method `triggerManualSync()`:
```dart
  Future<SyncResult> triggerManualSync() async {
    if (kLocalMode) return const SyncResult();
    ...
```

Di method `syncToServer()`:
```dart
  Future<SyncResult> syncToServer({
    Future<bool> Function(Map<String, dynamic> item)? kirim,
    bool force = false,
  }) async {
    if (kLocalMode) return const SyncResult();
    ...
```

- [ ] **Step 2: Pasang guard pada `lib/services/connectivity_service.dart`**

Di method `checkConnection()`:
```dart
  Future<bool> checkConnection() async {
    if (kLocalMode) {
      _setOnline(true);
      return true;
    }
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/health')).timeout(const Duration(seconds: 3));
      final ok = res.statusCode >= 200 && res.statusCode < 500;
      _setOnline(ok);
      return ok;
    } catch (_) {
      _setOnline(false);
      return false;
    }
  }
```

- [ ] **Step 3: Pasang guard pada `lib/services/api_service.dart`**

Di method `getTransaksi()`:
```dart
  static Future<List<Transaksi>> getTransaksi({
    String? jenis, int limit = 100,
  }) async {
    if (kLocalMode) {
      return LocalDb.getTransaksi(jenis: jenis, limit: limit);
    }
    List<Transaksi> server = [];
    ...
```

- [ ] **Step 4: Nonaktifkan banner sync di `lib/main.dart`**

Di `lib/main.dart`:
Baris 73:
```dart
if (!kIsWeb && !kLocalMode && ConnectivityService.instance.isOnline) {
  SyncService.instance.pullFromServer();
}
```
Baris 160:
```dart
if (online && !kIsWeb && !kLocalMode) {
  setState(() => _showSyncBanner = true);
  await SyncService.instance.syncToServer();
  await _updatePendingCount();
  await Future.delayed(const Duration(seconds: 3));
  if (mounted) setState(() => _showSyncBanner = false);
}
```

- [ ] **Step 5: Verifikasi kompilasi**

Run: `flutter analyze lib/services/sync_service.dart lib/services/connectivity_service.dart lib/services/api_service.dart lib/main.dart`
Expected: 0 issues.

---

### Task 4: Layanan Ekspor Cadangan (Backup Service)

**Files:**
- Create: `lib/services/backup_service.dart`
- Test: `test/services/backup_service_test.dart`

**Interfaces:**
- Produces: `BackupService.exportBackupJson()`, `BackupService.exportAndShare(BuildContext context)`

- [ ] **Step 1: Tulis unit test untuk pembuatan JSON cadangan**

Buat file `test/services/backup_service_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mengfin/services/backup_service.dart';

void main() {
  test('generateBackupData menghasilkan format valid dengan 6 tabel', () {
    final data = BackupService.createBackupPayload({
      'akun': [{'id': 'a1', 'nama': 'Dompet'}],
      'anggaran': [],
      'goals': [],
      'notif_draft': [],
      'sync_queue': [],
      'transaksi': [{'id': 't1', 'nominal': 50000}],
    }, appVersion: '1.0.0');

    expect(data['format'], equals('mengfin-backup'));
    expect(data['version'], equals(1));
    expect(data['appVersion'], equals('1.0.0'));
    expect(data['exportedAt'], isNotNull);
    final tables = data['tables'] as Map<String, dynamic>;
    expect(tables.keys, containsAll(['akun', 'anggaran', 'goals', 'notif_draft', 'sync_queue', 'transaksi']));
    expect((tables['transaksi'] as List).length, equals(1));
  });
}
```

- [ ] **Step 2: Jalankan test untuk memverifikasi file belum ada**

Run: `flutter test test/services/backup_service_test.dart`
Expected: FAIL (file `backup_service.dart` belum ada).

- [ ] **Step 3: Implementasikan fungsi ekspor di `lib/services/backup_service.dart`**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../constants/app_colors.dart';
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
    'sync_queue',
    'transaksi',
  ];

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

  static Future<void> exportAndShare(BuildContext context) async {
    try {
      final payload = await generateFullBackup();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

      final tempDir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
      final filePath = '${tempDir.path}/mengfin-backup-$stamp.json';
      final file = File(filePath);
      await file.writeAsString(jsonStr, encoding: utf8);

      await AppPrefs.instance.setLastBackupTime(DateTime.now().toIso8601String());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'mengfin-backup-$stamp.json',
          text: 'Berkas Cadangan Database MengFin ($stamp)',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengekspor cadangan: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }
}
```

- [ ] **Step 4: Tambahkan helper `lastBackupTime` di `AppPrefs`**

Buka `lib/services/app_prefs.dart`, tambahkan:
```dart
  static const _keyLastBackupTime = 'last_backup_time';
  String? get lastBackupTime => _prefs?.getString(_keyLastBackupTime);
  Future<void> setLastBackupTime(String val) async {
    await (await SharedPreferences.getInstance()).setString(_keyLastBackupTime, val);
  }
```

- [ ] **Step 5: Jalankan test untuk memverifikasi payload valid**

Run: `flutter test test/services/backup_service_test.dart`
Expected: PASS.

---

### Task 5: Layanan Pemulihan Cadangan (Restore Service)

**Files:**
- Modify: `lib/services/backup_service.dart`
- Test: `test/services/backup_service_test.dart`

**Interfaces:**
- Produces: `BackupService.validateBackupJson()`, `BackupService.restoreFromJsonString()`, `BackupService.pickAndRestore()`

- [ ] **Step 1: Tambahkan test validasi dan restore di `test/services/backup_service_test.dart`**

```dart
  test('validateBackupJson menolak format salah atau json rusak', () {
    expect(() => BackupService.validateBackupJson('bukan json'), throwsA(isA<FormatException>()));
    expect(() => BackupService.validateBackupJson('{"format": "asing"}'), throwsA(isA<Exception>()));
    expect(() => BackupService.validateBackupJson('{"format": "mengfin-backup", "version": 99}'), throwsA(isA<Exception>()));
  });

  test('validateBackupJson mengembalikan ringkasan untuk data valid', () {
    final validJson = jsonEncode({
      'format': 'mengfin-backup',
      'version': 1,
      'appVersion': '1.0.0',
      'exportedAt': '2026-10-16T10:00:00.000Z',
      'tables': {
        'transaksi': [{'id': '1'}],
        'akun': [{'id': 'a1'}],
      }
    });

    final summary = BackupService.validateBackupJson(validJson);
    expect(summary['transaksiCount'], equals(1));
    expect(summary['akunCount'], equals(1));
  });
```

- [ ] **Step 2: Jalankan test untuk memastikan test gagal**

Run: `flutter test test/services/backup_service_test.dart`
Expected: FAIL (method belum diimplementasikan).

- [ ] **Step 3: Implementasikan validasi & atomic restore di `lib/services/backup_service.dart`**

Tambahkan method berikut pada `BackupService`:
```dart
  static Map<String, dynamic> validateBackupJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Berkas cadangan tidak valid (bukan JSON objek).');
    }
    if (decoded['format'] != backupFormat) {
      throw Exception('Format cadangan tidak dikenali (${decoded['format']}).');
    }
    if (decoded['version'] != currentVersion) {
      throw Exception('Versi format cadangan (${decoded['version']}) tidak didukung.');
    }
    if (decoded['tables'] is! Map) {
      throw const FormatException('Struktur tabel tidak ditemukan dalam berkas.');
    }

    final tables = Map<String, dynamic>.from(decoded['tables'] as Map);
    final txList = (tables['transaksi'] as List?) ?? [];
    final akunList = (tables['akun'] as List?) ?? [];
    final anggaranList = (tables['anggaran'] as List?) ?? [];
    final goalsList = (tables['goals'] as List?) ?? [];

    return {
      'exportedAt': decoded['exportedAt']?.toString() ?? '-',
      'appVersion': decoded['appVersion']?.toString() ?? '-',
      'transaksiCount': txList.length,
      'akunCount': akunList.length,
      'anggaranCount': anggaranList.length,
      'goalsCount': goalsList.length,
      'tables': tables,
    };
  }

  static Future<void> restoreFromJsonString(String rawJson) async {
    final validation = validateBackupJson(rawJson);
    final tables = validation['tables'] as Map<String, dynamic>;

    final db = await LocalDb.db;
    await db.transaction((txn) async {
      // 1. Bersihkan 6 tabel
      for (final table in supportedTables) {
        try {
          await txn.delete(table);
        } catch (_) {}
      }

      // 2. Isi ulang dari cadangan
      for (final table in supportedTables) {
        final rows = tables[table];
        if (rows is List) {
          for (final row in rows) {
            if (row is Map) {
              await txn.insert(
                table,
                Map<String, dynamic>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      }
    });

    // 3. Picu notifikasi UI perubahan data
    AppEvents.instance.transaksiBerubah();
    AppEvents.instance.akunBerubah();
    AppEvents.instance.anggaranBerubah();
    AppEvents.instance.goalsBerubah();
    AppEvents.instance.notifDraftBerubah();
  }
```

- [ ] **Step 4: Jalankan test validasi**

Run: `flutter test test/services/backup_service_test.dart`
Expected: PASS.

---

### Task 6: UI Cadangan & Pemulihan di Layar Pengaturan

**Files:**
- Modify: `lib/screens/more_screen.dart`
- Consumes: `BackupService`, `AppPrefs`, `LocalDb`

- [ ] **Step 1: Tambahkan handler Ekspor & Impor di `_MoreScreenState`**

Di `lib/screens/more_screen.dart`, tambahkan method pemanggil dialog:
```dart
  Future<void> _handleExportBackup() async {
    await BackupService.exportAndShare(context);
    if (mounted) setState(() {});
  }

  Future<void> _handleRestoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      String jsonContent;
      if (pickedFile.bytes != null) {
        jsonContent = utf8.decode(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        jsonContent = await File(pickedFile.path!).readAsString();
      } else {
        throw Exception('Tidak bisa membaca isi berkas.');
      }

      final summary = BackupService.validateBackupJson(jsonContent);

      if (!mounted) return;
      final setuju = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text('Konfirmasi Pemulihan Cadangan', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data lokal saat ini akan DITIMPA sepenuhnya oleh data cadangan berikut:\n',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              Text('• Waktu Ekspor: ${summary['exportedAt']}'),
              Text('• Jumlah Transaksi: ${summary['transaksiCount']}'),
              Text('• Jumlah Dompet/Akun: ${summary['akunCount']}'),
              Text('• Anggaran: ${summary['anggaranCount']} · Goals: ${summary['goalsCount']}'),
              const SizedBox(height: 12),
              Text(
                'Tindakan ini tidak dapat dibatalkan. Lanjutkan?',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Timpa & Pulihkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (setuju != true) return;

      await BackupService.restoreFromJsonString(jsonContent);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Data berhasil dipulihkan dari cadangan!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal memulihkan cadangan: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }
```

- [ ] **Step 2: Tambahkan seksi UI "CADANGAN & PEMULIHAN" di dalam `build` `more_screen.dart`**

Tempatkan di atas seksi `SINKRONISASI & DATABASE`:
```dart
          _sectionLabel('CADANGAN & PEMULIHAN (BACKUP)'),
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Status Cadangan', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    FutureBuilder<int>(
                      future: LocalDb.getTransaksiCount(),
                      builder: (_, snap) => Text('${snap.data ?? 0} Transaksi tersimpan', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppPrefs.instance.lastBackupTime != null
                      ? 'Terakhir diekspor: ${AppPrefs.instance.lastBackupTime}'
                      : 'Belum pernah mengekspor cadangan',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_outlined, size: 16),
                        label: const Text('Ekspor Cadangan'),
                        onPressed: _handleExportBackup,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.file_download_outlined, size: 16),
                        label: const Text('Pulihkan Data'),
                        onPressed: _handleRestoreBackup,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
```

- [ ] **Step 3: Modifikasi tile "Laporkan Bug / Saran" dan "Keluar"**

Di `more_screen.dart`:
```dart
          if (!kLocalMode)
            _menuTile(
              icon: Icons.bug_report_outlined,
              color: const Color(0xFF10B981),
              title: 'Laporkan Bug / Saran',
              subtitle: 'Kirim masukan langsung ke developer',
              onTap: () => FeedbackSheet.show(context),
            ),
```
Dan pada `_handleLogout`: Jika `kLocalMode`, tampilkan dialog konfirmasi reset data lokal daripada sekadar memanggil `AuthService.logout()`.

- [ ] **Step 4: Verifikasi kompilasi**

Run: `flutter analyze lib/screens/more_screen.dart`
Expected: 0 issues.

---

### Task 7: Degradasi Graceful Fitur Server

**Files:**
- Modify: `lib/services/update_service.dart:137-142`
- Modify: `lib/services/api_service.dart:902-905`
- Modify: `lib/screens/scan_screen.dart:157, 768-781`
- Modify: `lib/screens/import_csv_screen.dart:114-118`

**Interfaces:**
- Consumes: `kLocalMode` from `lib/constants/config.dart`
- Produces: Pesan informatif dan bypass request backend

- [ ] **Step 1: Bypass backend pada `UpdateService`**

Di `lib/services/update_service.dart`:
```dart
    // 2) Backend sebagai cadangan (hanya jika bukan mode lokal)
    if (!kLocalMode) {
      try {
        final hasil = await _cekBackend();
        _hasChecked = true;
        return hasil;
      } catch (e) {
        ...
      }
    }
```

- [ ] **Step 2: Bypass query server AI pada `ApiService.aiChat`**

Di `lib/services/api_service.dart`:
```dart
    // 3. Online Server AI Query dengan timeout responsif (20 detik)
    if (_online && !kLocalMode) {
      try {
        final res = await _post(
          '/ai/chat',
          {'pesan': t},
          timeout: const Duration(seconds: 20),
        );
        ...
```

- [ ] **Step 3: Degradasi pada `lib/screens/scan_screen.dart`**

Di method `_scanStruk`:
```dart
      // 2. Fallback ke Gemini AI jika lokal gagal
      if (data == null) {
        if (kLocalMode) {
          throw Exception('OCR lokal tidak mendeteksi nominal. Fitur AI Cloud sedang diparkir di mode lokal.');
        }
        data = await ApiService.scanStruk(base64Encode(bytes), _mimeType);
        _sumberOcr = 'ai';
      }
```
Dan pada widget tree baris 768:
```dart
      if (_sumberOcr == 'lokal' && !kLocalMode) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _scanning ? null : () => _scanStruk(forceAi: true),
          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
          label: const Text('Coba dengan AI (Gemini)'),
          ...
        ),
      ],
```

- [ ] **Step 4: Guard PDF pada `lib/screens/import_csv_screen.dart`**

Di `lib/screens/import_csv_screen.dart`:
```dart
      if (isPdf) {
        if (kLocalMode) {
          _timer?.cancel();
          setState(() {
            _loading = false;
            _error = 'Impor E-Statement PDF memerlukan parser server yang sedang diparkir. Silakan gunakan format CSV atau input manual.';
          });
          return;
        }
        final base64 = base64Encode(bytes);
        ...
```

- [ ] **Step 5: Verifikasi kompilasi**

Run: `flutter analyze lib/services/update_service.dart lib/screens/scan_screen.dart lib/screens/import_csv_screen.dart`
Expected: 0 issues.

---

### Task 8: Penyesuaian Pipeline CI (.github/workflows/build.yml)

**Files:**
- Modify: `.github/workflows/build.yml:73-86`

- [ ] **Step 1: Perbarui release notes di `.github/workflows/build.yml`**

Ubah release notes pada step `Upload APK to Release` untuk merefleksikan mode lokal:
```yaml
          body: |
            ## 📱 MengFin Android APK (${{ steps.version.outputs.VERSION }}) - Mode Lokal
            
            ### ✨ Pembaruan Mode Lokal (Offline-First):
            - **100% Mode Lokal**: Berjalan mandiri tanpa dependensi server backend
            - **Backup & Restore JSON**: Ekspor dan impor seluruh data (6 tabel database lokal)
            - **Bypass Login**: Langsung masuk dashboard tanpa login Google
            - **Keamanan Sidik Jari**: Proteksi biometrik tetap aktif untuk profil lokal
            - **Degradasi Anggun**: Cek update langsung via GitHub Releases, OCR struk on-device ML Kit
            - **Performa Ringan**: APK split per-ABI (<25 MB) dengan proteksi Dart obfuscation
```

- [ ] **Step 2: Verifikasi sintaks workflow**

Pastikan blok YAML valid dan tidak mengubah konfigurasi keystore.

---

### Task 9: Verifikasi Menyeluruh & Uji Coba

**Files:**
- Test: Seluruh unit test dan static analysis

- [ ] **Step 1: Jalankan seluruh test unit**

Run: `flutter test`
Expected: Seluruh test lulus (PASS) tanpa kegagalan.

- [ ] **Step 2: Jalankan analisis kode Dart**

Run: `flutter analyze`
Expected: `No issues found!` (atau hanya info/linter non-blocking yang sudah ada sebelumnya).

- [ ] **Step 3: Uji Checklist HP Fisik**
1. Install APK hasil build lokal / CI menimpa versi lama di HP.
2. Pastikan app langsung membuka dashboard beranda.
3. Buat 1 dompet baru dan 1 transaksi baru -> verifikasi tersimpan.
4. Buka menu Lainnya -> Tekan "Ekspor Cadangan" -> file JSON terunduh/terbagikan.
5. Tambah transaksi sembarang (dummy).
6. Tekan "Pulihkan Data" -> pilih file JSON cadangan tadi -> verifikasi data dummy hilang dan data kembali persis.
7. Coba pulihkan file CSV laporan -> verifikasi ditolak dengan notifikasi kesalahan yang sopan tanpa crash.
