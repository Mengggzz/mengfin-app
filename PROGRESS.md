# Lanjutan pekerjaan cashflow — status per 28 Sep 2026

Berkas ini catatan proses supaya bisa dilanjutkan. Hapus kalau sudah selesai.

## Permintaan asal
"Beberapa fitur belum berjalan functionnya — analisa dan perbaiki."
Cara kerja yang dipilih pengguna: kerjakan satu per satu, dicek dulu tiap selesai.

## Daftar fitur mati yang ditemukan (dengan bukti)
1. `more_screen.dart:96` — tile "Tentang MengFin" `onTap: () {}`. ✅ diperbaiki (79ea311)
2. `widgets.dart:652` — `_opGroup()` mati; `×`/`÷` cuma `Text`. ✅ diperbaiki (79ea311)
3. `transaction_input_screen.dart:351` — `onEquals: () {}`. ✅ diperbaiki (79ea311)
4. `settings_screen.dart` — toggle/kata kunci/dompet hanya state lokal; Simpan cuma
   `Navigator.pop`; chevron tanpa aksi. ✅ diperbaiki (sesi ini, belum dipush)
5. `api_service.dart` — tidak ada `updateTransaksi`. ✅ ditambahkan (sesi ini)
6. hapus anggaran/goals/transaksi tanpa try/catch. ✅ (sesi ini)
7. `transaksi_screen.dart:227` — `_filterBtn('Buka filter', ..., () {})`. ✅ (ef261a3)
8. Auto-catat notifikasi tanpa plugin. ✅ parser+service (e048903) + wiring UI (sesi ini).
   **Belum pernah diuji di HP nyata.**

## Selesai dan sudah dipush
- 79ea311 — ekspresi numpad (25 + 10 = 35, dulu 2510), Tentang MengFin, ×/÷, overflow 360dp.
- e048903 — notif_parser (18 tes) + app_prefs (6 tes) + notif_service + manifest listener.

## Selesai SESI INI (commit 8f7bf7e, sudah dipush; CI run sedang jalan)
1. **Auto-kategorikan:** tombol `auto_fix_high` di layar input dulu ikon hiasan —
   sekarang `KategoriOtomatis.tebak()` cari transaksi terakhir (≤30 hari) dengan
   deskripsi mirip; 10 tes (`test/kategori_otomatis_test.dart`). Layar: loading +
   snackbar hasil; kategori langsung berubah. Tidak ada tebakan kalau tak cocok.
2. **Banner Premium dibuang:** teks "Scan All memerlukan Premium" diganti netral
   tentang draft — tidak ada sistem premium di app ini.
3. Bug tes: cache `SharedPreferences` singleton lintas-test → nilai awal lewat
   `setMockInitialValues` saja bocor dari test sebelumnya; sekarang ditulis lewat
   setter `AppPrefs`. Chip kata kunci di bawah lipatan → test scroll dulu.

## Rilis
- v20260927-1002 (CI sha 5f74f49, sukses): app-release.apk 63.7 MB, 1 download.
  https://github.com/Mengggzz/mengfin-app/releases/tag/v20260927-1002
- CI sha 8f7bf7e sedang berjalan saat file ini ditulis.

## Verifikasi
- `flutter analyze` 0 error; `flutter test` **101 lulus**; `flutter build web --release` OK.

1. **Pengaturan benar-benar dipakai:**
   - `settings_screen.dart`: `muatAkun` injectable; Simpan → AppPrefs (dompet utama/tampil);
     toggle → `setNotifAktif` + `terapkanPreferensi` + alur izin; kata kunci +/× tersimpan
     langsung; chevron → `_PilihAplikasiDialog` (Android: daftar paket + cari; luar Android:
     dialog penjelasan); baris dompet bisa diketuk untuk jadi utama.
   - `dompet_view.dart` (baru): `saldoTampil` + `dompetAwal` (8 tes, `test/dompet_view_test.dart`).
   - `main.dart`: `AppPrefs.init()` blocking sebelum runApp; `muatPaketSendiri()` +
     `terapkanPreferensi()` non-blocking.
   - `dashboard_screen.dart`: kartu "Dompet Saya", donut, dan peringatan "melebihi saldo"
     ikut `DompetView.saldoTampil` (sebelumnya selalu `d.saldoTotal` server).
   - `test/settings_prefs_test.dart` 6 tes lulus. Jebakan: `AppPrefs.reset()` ikut menghapus
     mock SharedPreferences → nilai awal harus di-set ulang setelah reset.
   - Jebakan 2: MethodChannel tanpa plugin menjawab menggantung selamanya → spinner tak
     pernah settle; `daftarPaketTerpasang` diberi `.timeout(2s)`.
2. **Edit transaksi:**
   - `ApiService.updateTransaksi(id, body)` offline-aware (perbarui lokal dulu → server →
     antrean PUT) + `updateTransaksiRaw` + `LocalDb.updateTransaksiLocal` + cabang
     `PUT /transaksi` di `sync_service.dart`.
   - `TransactionInputScreen(edit: tx)` — form terisi, judul "Edit Transaksi"; baris
     transaksi di beranda / transaksi / kalender diketuk = buka edit.
   - Chip dompet layar input = daftar akun asli (bottom sheet, ada "Semua dompet"),
     default `DompetView.dompetAwal`, kirim `akun_id` (backend menyesuaikan saldo akun).
   - Hapus transaksi/anggaran/goals: try/catch + SnackBar "Gagal menghapus";
     `_delete(int id)` → `dynamic` (ObjectId server itu String).
3. Verifikasi: `flutter analyze` 0 error; `flutter test` **91 lulus**.

## Sisa pekerjaan
1. **Sebelum bilang selesai:** `flutter build web --release` (belum dijalankan lagi
   setelah perubahan sesi ini) lalu commit + push; pantau CI membangun APK
   (repo Mengggzz/mengfin-app, branch main). `flutter build apk` lokal GAGAL di mesin
   ini (JDK/Gradle) — sudah diketahui, serahkan ke CI.
2. **Uji di HP:** minta pengguna coba auto-catat: Settings → Auto-catat → aktifkan →
   beri izin → terima notifikasi transfer → cek transaksi masuk.
3. Perlu keputusan pengguna (sengaja belum dikerjakan):
   - `transaction_input_screen.dart` — ikon `auto_fix_high` + klaim "Otomatis kategorikan
     dari transaksi terakhir" tanpa aksi. Implementasikan atau buang teksnya?
   - `settings_screen.dart` — banner "Scan All memerlukan Premium" padahal tidak ada
     sistem premium. Buang frasanya?
   - 404 `/update/check` di produksi itu normal (app sudah query GitHub Releases) — bukan bug.

## Catatan mesin
- Backend lokal: `cd backend && node src/index.js` (port 3000).
- Flutter web: `flutter run -d web-server --web-port 8080 --web-hostname localhost`.
- Windows/MSYS: kill via `MSYS_NO_PATHCONV=1 taskkill /F /PID <pid>` (pid dari `netstat -ano | grep :3000`).

## 2026-09-27 — sinkronisasi online/offline dompet (commit 0d1f84d, CI sukses)
**Akar masalah:** `sync_queue` dengan `table_name='akun'` tidak punya cabang di
`SyncService.syncToServer()`. Kodenya:
```
for (final item in queue) { ... else if (method == 'DONE') {} ...
  await LocalDb.removeFromQueue(id); }
```
Tidak ada `else if akun` → dompet offline jatuh ke "tanpa operasi", lalu
**dihapus dari antrean padahal tidak pernah dikirim**. Dompet yang dibuat saat
offline hilang permanen begitu online kembali. Kedua, dompet tidak pernah
disimpan lokal sama sekali (tidak ada tabel `akun`), jadi pemilih dompet di
input transaksi kosong saat offline.

**Yang diperbaiki:**
1. Schema SQLite v3: tabel `akun` baru (`id`, `local_id`, `nama`, `jenis`,
   `saldo`, `warna`, `ikon`, `synced`). Migrasi lama (v1→v2, INTEGER→TEXT)
   dijaga oleh `if (oldVersion < 3)`; `_createSchema` membuat semua tabel
   sekaligus jadi v2→v3 hanya jalan sekali.
2. `LocalDb`: `insertAkunLocal`, `replaceAkunLocalToServer`,
   `updateAkunSaldoLocal`, `getAkunList` (gabungan lokal+server, urut nama),
   `upsertAkunList`.
3. `ApiService`: `createAkunRaw` + `updateAkunSaldoRaw` (dipakai SyncService);
   `getAkunList()` sekarang cache-terpadu (web = server langsung; mobile =
   simpan hasil server lalu kembalikan cache + dompet lokal belum sync);
   `createAkun` & `updateAkunSaldo` menulis cache lokal supaya UI konsisten.
4. `SyncService.syncToServer`: cabang `POST /akun` (ambil id server, ganti id
   lokal) + `PUT /akun/:id`. Parameter opsional `kirim` untuk tes pengiriman.

**Verifikasi:** `flutter analyze` 0 error; `flutter test` **113 lulus** (7 tes
baru di `test/sync_offline_test.dart`: dompet offline tersimpan, id lokal
ditimpa id server, saldo offline bisa diubah, daftar dompet gabungan, item
antrean akun benar-benar dikirim, item gagal tetap di antrean, regresi id
String pada delete/update transaksi); `flutter build web --release` OK;
0 `localhost:3000` di `main.dart.js`. CI sukses untuk 0d1f84d.

**Sisa:** uji auto-catat notifikasi di HP nyata (plugin Android belum pernah
dijalankan di mesin ini). `flutter build apk` lokal tetap GAGAL (JDK/Gradle).

## 2026-09-27 (2) — dua bug UI (commit 9b040d8, CI sukses)
1. **Dialog "Sudah Versi Terbaru" muncul saat buka aplikasi.**
   `DashboardScreen._autoCheckUpdate()` memanggil `UpdateFlow.run(context)`
   TANPA `silentWhenNoUpdate: true`. Padahal `UpdateFlow.run` menampilkan
   `InfoDialog` untuk SEMUA hasil cek (update / sudah terbaru / error) kecuali
   flag itu diset. Jadi setiap kali app dibuka, dialog info muncul.
   Fix: `UpdateFlow.run(context, silentWhenNoUpdate: true)` + hapus cek
   ganda di dashboard. Tombol manual di MoreScreen tetap pakai default
   (tampilkan info) karena pengguna memang ingin tahu hasilnya.
2. **Pengaturan Kazz Utama tidak berdampak ke beranda.**
   `SettingsScreen._simpan()` sudah benar menulis AppPrefs dan memancarkan
   `AppEvents.akunBerubah()`, tapi `DashboardScreen` hanya memasang listener
   pada `transaksi` & `anggaran` — tidak ada yang mendengarkan `akun`.
   Akibatnya saldo "Dompet Saya" di beranda tetap pakai pilihan lama sampai
   aplikasi dibuka ulang. Fix: pasang + lepas listener `akun` juga.
   Catatan: layar yang sudah ada di IndexedStack (Home/Kazz/View/More)
   mendapat listener masing-masing; anggaran & goals dibuka lewat
   Navigator.push dan selalu `_load()` saat dibuka, jadi mereka selalu segar.

## Analisis struktur — temuan
Dipindai: TODO/FIXME (0), handler kosong (0), print debug di lib/ (8, di
dashboard_screen & auth_service — tidak fatal tapi sebaiknya diganti logging),
catch tanpa feedback di service (27 — sebagian besar sudah sengaja: offline
path jatuh ke queue, dan `Penyimpanan` sudah membungkus save layar).

Yang **OK** (bukan bug):
- _load() ulang dipanggil setelah create/update/delete di anggaran, goals,
  kazz, dashboard, transaksi, kalender.
- IndexedStack di MainNav: instance layar baru per build sudah disengaja
  supaya ganti mode tampilan langsung efektif (state tetap, tidak dibuat ulang).
- Connectivity listener di MainNav tidak di-cancel: MainNav adalah root,
  hidup seumur app — tidak ada leak yang berarti.

Yang **masih perlu uji di HP** (tidak bisa diverifikasi di mesin ini):
- Plugin Android notifikasi (auto-catat): belum pernah dijalankan.
- Migrasi DB v1→v3 di perangkat yang sudah punya DB lama — baru diuji
  dari skema baru (onCreate). Migrasi onUpgrade berjalan otomatis saat
  versi DB naik, tapi tidak ada tes yang membuat DB v1 dulu.

## 2026-09-27 — sinkronisasi saldo dompet (commit c4cab2b, CI sukses)
**Bug:** menu Kazz & beranda menampilkan saldo tidak berubah setelah transaksi
create/update/delete. Penyebab: backend mengubah saldo akun di server, tapi app
tidak pernah menarik ulang daftar akun → cache stale sampai restart.

**Perbaikan:**
1. ApiService.pullAkun (baru): GET `/akun` dari server, simpan ke lokal,
   lalu `AppEvents.akunBerubah()` agar Kazz/beranda menyegarkan diri.
2. createTransaksi/updateTransaksi/deleteTransaksi online: panggil pullAkun
   setelah operasi server sukses.
3. SyncService.pullFromServer: tarik akun sesudah sync queue selesai
   (offline batch flush).
4. Tes baru: test/saldo_sync_test.dart (4 tes integrasi).

## 2026-09-28 — migrasi DB v1→v3 teruji (commit berikutnya)
Tulis tes yang benar-benar membangun database versi 1 (`id INTEGER`) dan
menaikkan ke v3 (`id TEXT`, tambah tabel `akun`). Jalur `onUpgrade` yang sebelumnya
tidak pernah diuji kini aman.
