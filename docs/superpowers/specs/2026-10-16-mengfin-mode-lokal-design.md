# Desain Arsitektur: MengFin Mode Lokal (Tanpa Backend)

- **Tanggal:** 2026-10-16
- **Status:** Disetujui
- **Target Repo:** `Mengggzz/mengfin-app` (`C:\Users\NAN\Desktop\cashflow`)

---

## 1. Konteks & Tujuan
Backend server (Node.js di Railway) dihentikan karena ketiadaan hosting gratis yang stabil. Aplikasi MengFin dialihkan menjadi aplikasi **100% lokal (offline-first)**. Mekanisme sinkronisasi cloud digantikan oleh fitur **Ekspor/Impor Cadangan (Backup & Restore)** berbasis file JSON berversi.

**Prinsip Desain Utama:**
1. **Zero Deletion:** Seluruh kode yang berkomunikasi dengan backend tidak dihapus, melainkan diparkir menggunakan guard `kLocalMode`. Jika server kembali tersedia di masa depan, sistem dapat diaktifkan kembali hanya dengan passing parameter `API_BASE_URL`.
2. **Atomic Replacement:** Impor backup mengganti seluruh isi 6 tabel database lokal dalam satu transaksi SQLite (`db.transaction`). Jika terjadi kegagalan/korupsi format di tengah proses, perubahan otomatis di-rollback tanpa meninggalkan database dalam status setengah terisi.
3. **No Phantom Requests:** Di mode lokal, tidak boleh ada request HTTP yang keluar ke server backend mati (menghindari timeout, lag, dan baterai boros).

---

## 2. Definisi Mode Lokal (`kLocalMode`)
**File:** `lib/constants/config.dart`

```dart
const String _kApiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');
const bool kLocalMode = _kApiBaseUrlOverride == '' || _kApiBaseUrlOverride == 'local';
const String kApiBaseUrl = kLocalMode ? '' : _kApiBaseUrlOverride;
```

- Jika build dijalankan tanpa argumen `--dart-define=API_BASE_URL`, maka `kLocalMode` bernilai `true` dan `kApiBaseUrl` bernilai string kosong.
- URL produksi Railway lama dihapus agar tidak pernah ada koneksi liar ke endpoint yang sudah nonaktif.

---

## 3. Autentikasi & Alur Masuk (Startup)
**File:** `lib/main.dart`, `lib/services/auth_service.dart`

1. **Rute Awal (`initialRoute`):**
   - Di `lib/main.dart`, `initialRoute` langsung mengarah ke `/home` jika `kLocalMode || AuthService.instance.isLoggedIn`. Pengguna tidak akan melihat layar login Google saat instalasi baru.
2. **Profil Pengguna Lokal:**
   - Di `AuthService`:
     - `isLoggedIn`: Selalu mengembalikan `true` bila `kLocalMode` aktif.
     - `user`: Mengembalikan profil statis `{'nama': 'Pengguna Lokal', 'email': 'lokal@mengfin.app'}` jika belum ada user tersimpan.
     - `signInWithGoogle()`: Diberi guard `if (kLocalMode) return true;`.
3. **Kunci Biometrik:**
   - Fitur kunci sidik jari / PIN lokal (`AppPrefs.instance.biometricAktif`) tetap berfungsi penuh karena memanfaatkan flag `isLoggedIn == true`.
4. **Logout / Keluar:**
   - Tombol "Keluar" di menu Lainnya tetap ditampilkan namun dialihkan fungsinya untuk mereset data sesi/lokal dengan dialog konfirmasi peringatan.

---

## 4. Penonaktifan Sinkronisasi & Jaringan
**File:** `lib/services/sync_service.dart`, `lib/services/connectivity_service.dart`, `lib/services/api_service.dart`

1. **SyncService:**
   - `pullFromServer()`: Guard `if (kLocalMode) return;` di baris pertama.
   - `syncToServer()`: Guard `if (kLocalMode) return const SyncResult();`.
   - `triggerManualSync()`: Guard `if (kLocalMode) return const SyncResult();`.
   - Antrean `sync_queue` di SQLite tetap dicatat oleh `LocalDb.enqueue` (kode diparkir) tetapi worker sync tidak memprosesnya ke jaringan.
2. **ConnectivityService:**
   - Heartbeat ping ke `$kApiBaseUrl/health` dinonaktifkan jika `kLocalMode`.
   - `checkConnection()` tidak memanggil HTTP saat `kLocalMode`.
3. **ApiService:**
   - `getTransaksi()` langsung mengambil data dari `LocalDb.getTransaksi()` tanpa mencoba fetch jaringan saat `kLocalMode`.

---

## 5. Subsistem Cadangan & Pemulihan (Backup & Restore)
**File Baru:** `lib/services/backup_service.dart`

### 5.1 Format Dokumen Cadangan JSON
Cadangan mengekspor 6 tabel database lokal: `akun`, `anggaran`, `goals`, `notif_draft`, `sync_queue`, dan `transaksi`.

```json
{
  "format": "mengfin-backup",
  "version": 1,
  "appVersion": "1.0.0",
  "exportedAt": "2026-10-16T14:30:00.000Z",
  "tables": {
    "akun": [ ... ],
    "anggaran": [ ... ],
    "goals": [ ... ],
    "notif_draft": [ ... ],
    "sync_queue": [ ... ],
    "transaksi": [ ... ]
  }
}
```

### 5.2 Alur Ekspor (Export)
1. Query semua baris dari 6 tabel melalui `LocalDb.db`.
2. Format menjadi JSON string dengan indentasi.
3. Tulis ke file temporary: `mengfin-backup-YYYYMMDD-HHmmss.json`.
4. Bagikan file melalui `SharePlus.instance.share(ShareParams(files: [XFile(filePath)]))`.
5. Simpan timestamp ekspor terakhir di `AppPrefs`.

### 5.3 Alur Pemulihan (Restore)
1. Buka file picker sistem via `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true)`.
2. Baca konten (baik dari `file.bytes` atau `File(file.path)`).
3. **Validasi Dokumen:**
   - Parse JSON harus menghasilkan `Map<String, dynamic>`.
   - Field `format` harus bernilai `"mengfin-backup"`.
   - Field `version` harus bernilai `1`.
   - Field `tables` harus berupa Map dan berisi key tabel valid.
   - Jika validasi gagal, kembalikan pesan error yang jelas (misal: "Format file cadangan tidak dikenali").
4. **Dialog Konfirmasi:**
   - Tampilkan rincian isi cadangan (jumlah transaksi, akun, anggaran, dll).
   - Pengguna harus menekan tombol konfirmasi sebelum proses penggantian data dieksekusi.
5. **Eksekusi Atomic Transaction:**
   ```dart
   final db = await LocalDb.db;
   await db.transaction((txn) async {
     for (final table in tables) {
       await txn.delete(table);
     }
     for (final entry in backupTables.entries) {
       for (final row in entry.value) {
         await txn.insert(entry.key, Map<String, dynamic>.from(row));
       }
     }
   });
   ```
6. **Notifikasi UI Event:**
   - Panggil `AppEvents.instance.transaksiBerubah()`, `akunBerubah()`, `anggaranBerubah()`, `goalsBerubah()`, `notifDraftBerubah()` untuk memperbarui tampilan seketika.

---

## 6. Antarmuka Pengguna (UI) di Menu Pengaturan
**File:** `lib/screens/more_screen.dart`

1. **Seksi "CADANGAN & PEMULIHAN":**
   - Info status: Waktu cadangan terakhir + total transaksi tersimpan saat ini.
   - Tombol **Ekspor Cadangan**: Membuka share dialog untuk menyimpan/mengirim file JSON.
   - Tombol **Pulihkan Cadangan**: Membuka pemilih file dan menampilkan konfirmasi penimpaan.
2. **Seksi "SINKRONISASI & DATABASE":**
   - Subtitle disesuaikan di mode lokal: "Penyimpanan lokal aktif · Tidak terhubung ke cloud".
3. **Degradasi Menu:**
   - Tombol "Laporkan Bug / Saran" disembunyikan jika `kLocalMode` aktif.

---

## 7. Degradasi Graceful Fitur Berbasis Server
1. **Pembaruan Aplikasi (`UpdateService`):**
   - Bypass pengecekan backend Railway. Cek pembaruan mengandalkan GitHub Releases API publik (`api.github.com/repos/Mengggzz/mengfin-app/releases/latest`).
2. **AI Chat Assistant (`ApiService.aiChat`):**
   - Panggilan HTTP ke `/ai/chat` dilewati. Langsung dialihkan ke `_localAIChat` yang memproses analisis finansial, ringkasan saldo, dan input transaksi secara lokal.
3. **Scan Struk & Mutasi (`scan_screen.dart`):**
   - OCR lokal via ML Kit tetap aktif.
   - Fallback tombol atau panggilan Gemini cloud dimatikan dengan notifikasi jelas.
4. **Impor E-Statement PDF (`import_csv_screen.dart`):**
   - File PDF ditolak di awal dengan pesan informatif: *"Impor E-Statement PDF memerlukan parser server yang sedang diparkir. Gunakan format CSV atau input manual."* File CSV tetap diparse 100% lokal.

---

## 8. Penyesuaian CI / Build Pipeline
**File:** `.github/workflows/build.yml`

1. Perintah build tetap menggunakan:
   `flutter build apk --split-per-abi --obfuscate --split-debug-info=build/debug-info --release --android-skip-build-dependency-validation --dart-define=APP_BUILD_TAG=${{ steps.version.outputs.VERSION }}`
2. Konfigurasi signing 4 secret (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`) tetap dipertahankan tanpa perubahan agar update APK dapat diinstal menimpa versi sebelumnya di HP pengguna.
3. Release notes otomatis diperbarui dengan deskripsi mode lokal dan fitur cadangan JSON.

---

## 9. Rencana Verifikasi & Pengujian
1. **Unit Test:**
   - `test/services/backup_service_test.dart`: Ekspor 6 tabel ke JSON, validasi format, restore replace tabel, penolakan file JSON tidak valid.
2. **Static Analysis:**
   - Jalankan `flutter analyze` untuk memastikan tidak ada compiler error atau warning kritis.
3. **Pengujian Manual di HP Fisik:**
   - Verifikasi alur tanpa login, persistensi data transaksi, ekspor cadangan ke file storage, penambahan data dummy, pemulihan data dari cadangan, serta penolakan file non-cadangan.
