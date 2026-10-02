# Lanjutan pekerjaan cashflow — status per 28 Sep 2026

Berkas ini catatan proses supaya bisa dilanjutkan. Hapus kalau sudah selesai.

## STATUS SAAT INI (baca dulu)
Semua permintaan asal SELESAI dan teruji. Hanya 1 item terbuka: uji plugin
notifikasi di HP nyata. Untuk mulai lagi: baca bagian ini, lalu lihat
"Riwayat perbaikan" di bawah untuk konteks tiap commit.

- Repo: `C:\Users\NAN\Desktop\cashflow`, branch `main`, remote
  https://github.com/Mengggzz/mengfin-app.git
- Kondisi terakhir: HEAD `3f1bf02`, `flutter analyze` 0 error,
  `flutter test` 125 lulus, `flutter build web --release` OK,
  0 `localhost:3000` di `build/web/main.dart.js`. CI sukses tiap commit.
- `flutter build apk` GAGAL lokal (JDK/Gradle 8.14.1 tidak cocok) —
  serahkan ke CI "Build & Release APK" saja.

### TERBUKA — belum dikerjakan
1. **Uji plugin notifikasi di HP** (tidak bisa di mesin ini):
   pasang APK rilis → Settings → Auto-catat → aktifkan + beri izin →
   terima notifikasi transfer (GoPay/DANA/BCA) → cek transaksi masuk
   sebagai draft. Parser murni sudah lulus (18 tes), tapi plugin
   `notification_listener_service` belum pernah berjalan di perangkat.
   Lihat `lib/services/notif_service.dart`, `notif_parser.dart`,
   `app_prefs.dart`.

### SELESAI — jangan kerjakan lagi (sudah ada tes + CI sukses)
- Fitur mati (numpad, Tentang MengFin, filter, ×/÷, ikon hiasan) — 79ea311
- Pengaturan benar-benar dipakai (AppPrefs, dompet utama/tampil, notif, keyword)
- Edit/hapus transaksi offline-aware (`updateTransaksi`, id String)
- Auto-kategorikan + buang banner Premium — 8f7bf7e
- Sinkronisasi dompet offline (cabang `akun` di sync_queue) — 0d1f84d
- Dialog "Sudah Versi Terbaru" saat buka aplikasi — 9b040d8
- Pengaturan Kazz Utama tidak dampak beranda (listener `akun`) — 9b040d8
- Sinkronisasi saldo dompet menu Kazz (`pullAkun`) — c4cab2b
- Migrasi DB v1→v3 teruji (data lama tidak hilang) — 3f1bf02

### Info mesin
- Backend lokal: `cd backend && node src/index.js` (port 3000).
- Flutter web: `flutter run -d web-server --web-port 8080 --web-hostname localhost`.
- Windows/MSYS: kill via `MSYS_NO_PATHCONV=1 taskkill /F /PID <pid>`
  (pid dari `netstat -ano | grep :3000`).
- Tes SQLite: `sqflite_common_ffi` + `LocalDb.overridePathForTest`;
  panggil `d.delete('akun')` dll. di `setUp` karena DB dibagi antar-test.

## Permintaan asal
"Beberapa fitur belum berjalan functionnya — analisa dan perbaiki."
Cara kerja yang dipilih pengguna: kerjakan satu per satu, dicek dulu tiap selesai.
Semua sudah dikerjakan — lihat "SELESAI" di atas.

## Riwayat perbaikan (komit, urut lama→baru)
79ea311 ekspresi numpad, Tentang MengFin, ×/÷, overflow 360dp.
e048903 notif_parser (18 tes) + app_prefs (6 tes) + notif_service + manifest.
5f74f49 pengaturan dipakai sungguhan + edit transaksi + dompet di input.
8f7bf7e auto-kategorikan + buang banner Premium.
0d1f84d sinkronisasi dompet offline (cabang `akun` di sync_queue).
9b040d8 dua bug UI: dialog "sudah terbaru" + listener `akun` di beranda.
c4cab2b sinkronisasi saldo dompet menu Kazz (`pullAkun`).
3f1bf02 tes migrasi DB v1→v3.

### 79ea311, e048903 — fitur mati
Numpad: `25 + 10` dulu jadi `2510`; tombol `×`/`÷` cuma `Text` tanpa aksi.
Tentang MengFin, filter "Buka filter", overflow 360dp, ikon hiasan.

### 5f74f49 — pengaturan dipakai sungguhan
- `settings_screen.dart`: `muatAkun` injectable; Simpan → AppPrefs (dompet
  utama/tampil); toggle → `setNotifAktif` + `terapkanPreferensi` + alur izin;
  kata kunci +/× tersimpan langsung; chevron → `_PilihAplikasiDialog`;
  baris dompet bisa diketuk jadi utama.
- `dompet_view.dart` (baru): `saldoTampil` + `dompetAwal`.
- `main.dart`: `AppPrefs.init()` blocking sebelum runApp.
- `dashboard_screen.dart`: "Dompet Saya" ikut `DompetView.saldoTampil`.
- Edit transaksi: `ApiService.updateTransaksi` offline-aware;
  `TransactionInputScreen(edit: tx)`; ketuk baris = buka edit;
  chip dompet asli + `akun_id` (backend sesuaikan saldo).
- Jebakan: `AppPrefs.reset()` ikut hapus mock SharedPreferences → nilai awal
  harus di-set ulang setelah reset. Chip kata kunci di bawah lipatan → scroll
  dulu. `daftarPaketTerpasang` perlu `.timeout(2s)` (MethodChannel tanpa
  plugin menggantung selamanya).

### 0d1f84d — sinkronisasi dompet offline
`sync_queue` dengan `table_name='akun'` tidak punya cabang di
`SyncService.syncToServer()` → item dihapus dari antrean tanpa pernah
dikirim. Dompet yang dibuat offline hilang permanen. Selain itu dompet tidak
pernah disimpan lokal sama sekali (pemilih dompet kosong saat offline).
Fix: schema v3 (tabel `akun`), `insertAkunLocal`/`replaceAkunLocalToServer`/
`updateAkunSaldoLocal`/`getAkunList`/`upsertAkunList`, cabang POST/PUT `/akun`.

### 9b040d8 — dua bug UI
1. Dialog "Sudah Versi Terbaru" tiap buka aplikasi:
   `_autoCheckUpdate` memanggil `UpdateFlow.run` tanpa `silentWhenNoUpdate`.
2. Pengaturan Kazz Utama tidak dampak beranda: `_simpan` sudah pancarkan
   `akunBerubah()` tapi DashboardScreen tak punya listener `akun`.

### c4cab2b — saldo dompet menu Kazz tidak sinkron
Backend ubah saldo akun saat transaksi, tapi app tak pernah tarik ulang.
Fix: `ApiService.pullAkun` (GET `/akun` → cache → `akunBerubah()`);
create/update/delete transaksi online memanggilnya; `pullFromServer` juga.

### 3f1bf02 — tes migrasi DB v1→v3
`test/migrasi_db_test.dart` membangun DB v1 betulan (`id INTEGER`, tanpa
tabel `akun`) lalu menaikkan ke v3. Sebelumnya hanya `onCreate` yang teruji.

## Rilis
- v20260927-1002 (CI 5f74f49): app-release.apk 63.7 MB
  https://github.com/Mengggzz/mengfin-app/releases/tag/v20260927-1002
- v20260927-1054, dan rilis otomatis tiap commit sesudahnya (CI sukses).

## Catatan mesin
- Windows/MSYS; `flutter build apk` GAGAL (JDK/Gradle 8.14.1) → pakai CI.
- `flutter test` satuan: `flutter test --no-pub test/<file>.dart`.
  `pumpAndSettle` menggantung di dialog animasi → pakai `pump` + tutup
  manual lewat `tester.state(find.byType(Navigator).first).pop()`.

## Responsif layout & Bug Fixes Komprehensif (2 Oct 2026)
Ditambahkan `lib/utils/responsive.dart` dengan:
- Breakpoints Bootstrap-style (xs, sm, md, lg, xl, xxl)
- ResponsiveContainer: padding & max-width responsif
- ResponsiveRow: grid column otomatis berdasarkan lebar layar
- ResponsiveWidget: child berbeda per breakpoint
- ResponsiveText: font size scaling

Perbaikan Bug Komprehensif:
1. `kazz_screen.dart`: input saldo tidak reset saat keyboard muncul (TextEditingController dipindah keluar builder scope), try/catch deleteAnggaran.
2. `transaction_input_screen.dart`: `resizeToAvoidBottomInset: false` + padding `viewInsets.bottom + 8`, mounted check di `_onConfirm`.
3. `settings_screen.dart`: `terpilih` dipindah dari build lokal ke `State` field `late Set<String> terpilih` diinisialisasi pada `initState()` (_PilihAplikasiDialog), mounted check & error handling.
4. `dashboard_screen.dart`: mounted check di `_autoCheckUpdate`, `_load`, `_DayDetailSheetState._load`, callback `.then()`; `TextEditingController` dispose di `_editBudgetHarian()`; mutasi `_insightPage` di onPageChanged.
5. `transaksi_screen.dart`: mounted checks di `_load()`, `_editTransaksi()`, `_delete()`, serta `DateTime.tryParse`.
6. `analytics_screen.dart`: `DateTime.tryParse` tanggal transaksi, perbaiki string escape `'\${value}'` -> `'${value}'`, mounted check `_loadData()`.
7. `anggaran_screen.dart`: `TextEditingController` di luar `StatefulBuilder` builder scope, mounted check di `_load()`.
8. `calendar_screen.dart`: mounted check di `_load()` & `_hapusTransaksi()`, race condition guard `_loadGen`.
9. `ai_screen.dart`: mounted check di `Future.delayed`.
10. `more_screen.dart`: try/catch error handling di `_handleLogout`.
11. `login_screen.dart`: try/catch reset `_loading = false` pada branch web.
12. `scan_screen.dart`: konsolidasi multi-setState dan `DateTime.tryParse`.
13. `laporan_screen.dart`: optimasi `_loadCompare` memanfaatkan `_allTx` yang sudah ada tanpa redundant fetch.
14. `connectivity_service.dart`: simpan subscription `_sub` dan `cancel()` di `dispose()`.
15. `local_db.dart`: DB init future lock (`_dbFuture`), bersihkan table `akun` dan `sync_queue` di `clearAll()`.
16. `sync_service.dart`: bypass dead-letter item agar antrean sync tidak terblokir.
17. `api_service.dart`: verifikasi HTTP status code di `_delete()`.
19. Fix Blank Loading Screen & Slow Batch Sync (Video Bug):
    - `dashboard_screen.dart`: tambah `_loadLocalCacheFirst()` untuk render instan data lokal saat startup; `_load()` tidak lagi menghapus tampilan (`_loading = true`) jika data lama sudah ada (`_data != null`).
    - `local_db.dart`: tambah `upsertTransaksiBatch`, `upsertAnggaranBatch`, `upsertGoalBatch` pakai batch SQLite tunggal menggantikan sequential disk writes.
    - `api_service.dart` & `sync_service.dart`: gunakan batch operations untuk pull 200 data tanpa lag/thread-blocking.
    - `kazz_screen.dart`, `transaksi_screen.dart`, `anggaran_screen.dart`, `goals_screen.dart`, `analytics_screen.dart`: `_load()` hanya tampilkan full spinner jika data kosong (`isEmpty`), transisi antar-tab mulus tanpa flicker layar hitam.

## Analisis struktur (28 Sep 2026)
Dipindai: TODO/FIXME (0), handler kosong (0), kontrol mati (0).
8 `print(` debug di dashboard_screen & auth_service — tidak fatal.
27 `catch (_)` di service memang sengaja (offline jatuh ke queue; layar
dibungkus `Penyimpanan`).

Yang **OK**:
- `_load()` ulang setelah create/update/delete di anggaran, goals, kazz,
  dashboard, transaksi, kalender.
- IndexedStack MainNav: instance baru per build disengaja (mode tampilan);
  state tetap, tak dibuat ulang.
- Connectivity listener di MainNav tak di-cancel: root, hidup seumur app.
