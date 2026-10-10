# Lanjutan pekerjaan cashflow — status per 10 Okt 2026 (Bugfix Round 5)

Berkas ini catatan proses supaya bisa dilanjutkan. Hapus kalau sudah selesai.

## STATUS SAAT INI (baca dulu)
Semua perbaikan Fase A (Task 1, 1b, 1c, 1d, 1e, 1f) dari Task List Round 5 SELESAI dan teruji:
- `flutter test`: 175/175 test lulus (termasuk hint bulan, TouchEffect, FeedbackSheet, dll).
- `flutter analyze`: 0 error.
- `flutter build web --release`: Sukses (116.8s), 0 `localhost:3000` di JS bundle.
- Backend `POST /api/feedback`: Validasi, format HTML Telegram Bot API, dan fallback ke database `feedbacks` teruji lulus.

### Rincian Perbaikan Round 5 (Fase A):
1. **Task 1 — Hint bulan kosong kartu "Saldo vs Pengeluaran" (`lib/screens/dashboard_screen.dart`, `lib/services/local_db.dart`)**:
   - `LocalDb.getBulanTerakhirTransaksi` mencari bulan transaksi sebelum bulan berjalan.
   - Hint muncul saat bulan berjalan Rp 0 dan ada data bulan sebelumnya: *"Bulan ini belum ada transaksi. Data terakhir: September 2026 — lihat ringkasannya di View/Laporan."* Tap hint membuka `LaporanScreen`.
2. **Task 1b — Hint budget harian (`lib/screens/dashboard_screen.dart:1426`)**:
   - `hintText: '20000'` diubah jadi `'0'` agar tidak tampak sebagai default.
3. **Task 1c — Samakan hintText nominal jadi '0'**:
   - `lib/screens/goals_screen.dart:84` (Tambah Dana): `hintText: '100.000'` → `'0'`.
   - `lib/screens/saldo_screen.dart:148` (Batas Anggaran): `hintText: '1.500.000'` → `'0'`.
   - `lib/screens/anggaran_screen.dart:124` (Batas Anggaran): `hintText: '1.500.000'` → `'0'`.
4. **Task 1d — Bentuk partikel per musim yang baru (`lib/widgets/season_background.dart`)**:
   - Semi: bunga 5 kelopak + titik tengah kuning muda (`0xFFFDE68A`).
   - Panas: kilau bintang 4-sisi kurva hangat.
   - Gugur: polygon daun maple 12 titik + tangkai garis.
   - Dingin: kristal salju 6-sisi stroke 0°/60°/120° + titik tengah.
   - Default: bokeh 2-lapis konsentris cyan.
5. **Task 1e — Efek animasi sentuhan permanen (`lib/widgets/touch_effect.dart`)**:
   - Widget `TouchEffect`: `AnimatedScale` 1.0 → 0.96 (120ms, `Curves.easeOut`).
   - Diterapkan ke: `QuickActionButton` (kartu fitur AI, Scan, Budget), `GlassCard(onTap: ...)`, item grid kategori transaksi (`CategoryIconGrid`), tombol tune beranda, dan `_menuTile` menu `MoreScreen`.
6. **Task 1f — Fitur "Laporkan Bug / Saran" (`lib/widgets/feedback_sheet.dart`, `backend/src/routes/feedback.js`, `backend/src/models.js`)**:
   - Frontend: Sheet dengan chip Bug / Saran, input judul singkat, input deskripsi multiline (min 10 karakter), info perangkat otomatis (`package_info_plus` + `device_info_plus`).
   - Backend: `POST /api/feedback` dengan validasi, kirim ke Telegram Bot API (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`), dan fallback otomatis ke MongoDB collection `feedbacks`.

### Rincian Perbaikan Round 4 (Fase A):
1. **Task 1 — Parser SeaBank `parseSeabankText` (`backend/src/services/estatement.js`)**:
   - Ekstraksi ringkasan dijangkar ke baris `TABUNGAN` (`text.match(/^.*TABUNGAN(\d[\d.,]*).*$/m)`) sehingga tidak tertipu tanggal periode `"01 SEP 2026"`.
   - Kandidat pasangan nominal & saldo diuji dari seluruh token secara mundur (backward pass); token sebelum blob angka otomatis menjadi deskripsi bersih dari nomor telepon footer CS (`+6221 5086 7070`).
   - Rantai saldo $|saldo_i - saldo_{i-1}| == nominal$ dan arah transaksi presisi.
2. **Task 2 — Transparansi AI Fallback Gemini (`backend/src/services/estatement.js`)**:
   - Loop `CANDIDATE_MODELS` menangkap error per model dengan `console.error` dan melempar pesan detail `"AI gagal: <sebab>"`, bukan menelan error diam-diam.
3. **Task 3 — Log Tahapan E-Statement (`backend/src/routes/scan.js`, `estatement.js`, `lib/screens/import_csv_screen.dart`, `lib/services/api_service.dart`)**:
   - Backend membangun array `stages[]` (`extract`, `detect`, `parse`, `ai_fallback`) dan menyertakannya di respons HTTP.
   - Frontend `ImportCsvScreen`: elapsed timer detik + tombol Batal saat proses; seksi collapsible "Log Proses" berisi tiap tahapan eksekusi dan durasi ms; card error menampilkan tahap yang gagal (`failed_stage`).
4. **Task 4 — Hardening Sinkronisasi (`backend/src/routes/akun.js`, `lib/services/local_db.dart`, `lib/services/sync_service.dart`, `lib/screens/more_screen.dart`)**:
   - 4a: `GET /akun` backend read-only murni (return `[]` jika kosong tanpa auto-create dompet).
   - 4b: `reconcileAkunSaldo()` selalu dipanggil pasca-pull di semua jalur sinkronisasi. Kasus Rp 2.000.000 − Rp 31.000 $\rightarrow$ Rp 1.969.000 terverifikasi.
   - 4c: Item gagal permanen (404/400/validasi/retry >= 5) ditandai `permanent_failed`, diabaikan dari `getQueue()` agar tidak di-loop selamanya, dan disurface ke user di `_SyncLogSheet`.
   - 4d: Cek kesehatan sync saat `pullFromServer()` membandingkan jumlah transaksi & akun lokal vs server; memicu rekonsiliasi otomatis jika ada diskrepansi.
   - 4e: Di `MoreScreen` ("Bersihkan & Reset"), `pullFromServer()` kini di-`await` di dalam dialog progres putar sebelum menampilkan SnackBar sukses, mencegah user melihat saldo 0 sementara.
5. **Task 5 — Partikel Musim (`lib/widgets/season_background.dart`)**:
   - Log debug pencatatan parameter render partikel ditambahkan. Partikel 6–14px, opacity 0.35–0.70, kecepatan 2x, dan bypass `disableAnimations` sistem terdokumentasi.
6. **Task 6 — Fallback AI Jujur (`backend/src/services/gemini.js`)**:
   - Timeout backend dinaikkan ke 20s (`withTimeout(..., 20000)`).
   - Fallback untuk input bebas/tak dikenal saat AI offline menjawab jujur *"Maaf, AI sedang tidak bisa dihubungi..."*, bukan dump "📊 Analisis Keuangan". Input hapus transaksi mengembalikan panduan terarah.

### Fitur & Optimasi Baru yang Selesai (Fase A):
1. **Package Name `com.mengfin`**: `build.gradle.kts`, `MainActivity.kt` di package `com.mengfin`.
2. **Pembersihan Permission**: Dihapus 8 permission tak terpakai dari `AndroidManifest.xml`.
3. **Timeout Scan Struk**: 60s timeout di `ApiService.scanStruk`.
4. **Scan Struk On-Device (ML Kit)**: `StrukParser` + `OcrService` + Fallback Gemini.
5. **Auto-Catat Lanjutan**: Deep link langsung `openNotificationListenerSettings`, Mode Scan Bukti Transfer / Mutasi (`POST /api/scan/mutasi`), Import CSV Mutasi Bank (`ImportCsvScreen`), Onboarding Wizard (`AutoNotifOnboardingSheet`).
6. **Fix Kunci Biometrik**: `canAuthenticate()` memverifikasi enrollment nyata, feedback SnackBar di `MoreScreen`.
7. **Fix Sync Queue**: Penundaan eksekusi PUT unresolved ID dan penandaan 404 sebagai `permanent_failed`.
8. **Fix Voice Input**: Guard `_processing` race condition dan penanganan `onError`.
9. **Dual Floating Button (Mic + Plus)**: Di sisi kanan bawah, 4-tab bottom nav simetris, chip Voice Text lama dihapus.
10. **Tema Musim & Animasi Partikel Background**: Default, Semi 🌸, Panas ☀️, Gugur 🍂, Dingin ❄️ dengan `SeasonBackground` custom painter.
11. **Redesign PDF Laporan**: Format profesional ber-header branded, 3 kartu summary, porsi kategori, dan tabel transaksi.
12. **Form Akun per Tipe**: Tabungan (target & progress), Kartu Kredit (limit & tempo), Aset Emas (gram & nilai), Net Worth kalkulasi.
13. **AI Chat Advisor Cerdas**: Resilient local routing, timeout 20s, quick reply chips, dan multi-bubble splitting.

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
- Rename Kazz -> Saldo & Kazz AI -> MengFin AI (UI strings) — 8d8e1e7
- Sinkronisasi DB penuh (segment pathId goals/progres, return Map createRaw, replace local id) — 8d8e1e7
- Perbaiki logika bot MengFin AI (prompt to-the-point terstruktur, filter kataAnalisis) — 8d8e1e7
- Sinkronisasi DB dasar (update sync_queue path, deleteAkun, post-pull events) — cbade9a
- Pengaturan Beranda persisten (homeDataMode, showChart, showBudget, quickActionOrder, homeTitle) — cbade9a
- Toggle switch Dark/Light mode (Switch.adaptive) — cbade9a
- Narasi AI laporan offline fallback kalkulasi lokal — cbade9a
- Edit judul & emoji header Home — cbade9a
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
20. Implementasi 4 Fitur Utama (Izin Sistem & Auto-Catat, Dompet Saya, Pemasukan Multi-Dompet, Auto-Kategori Pengeluaran):
    - `android/app/src/main/AndroidManifest.xml`: Menambahkan izin `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES`, `QUERY_ALL_PACKAGES`, `POST_NOTIFICATIONS` dan intent queries apps package visibility untuk integrasi sistem Android & deteksi aplikasi e-wallet/bank lokal.
    - `lib/services/permission_service.dart`: Helper terpusat untuk verifikasi dan request izin sistem (storage, notifikasi, query installed apps).
    - `lib/screens/settings_screen.dart`: Menampilkan status perizinan penyimpanan dan dialog interaktif daftar aplikasi keuangan/e-wallet yang dipantau auto-catat.
    - `lib/screens/dashboard_screen.dart`: Kartu "Dompet Saya" interaktif dengan bottom sheet switch dompet aktif / Semua Dompet, shortcut Tambah Dompet (`TambahKazzScreen`) dan Kelola Dompet (`KazzScreen`), serta sinkronisasi saldo dinamis.
    - `lib/screens/transaction_input_screen.dart`: Menyediakan selector dompet untuk transaksi pemasukan (otomatis masuk ke dompet tujuan), konfirmasi pemilihan dompet jika belum ditentukan, dan integrasi cerdas `KategoriOtomatis.tebakKamus` saat user mengetik deskripsi pengeluaran (contoh: "kopi" otomatis memilih kategori "Makan & Minum", "bensin" -> "Transportasi", dsb).
    - `lib/services/kategori_otomatis.dart`: Penambahan `tebakKamus` pemetaan ratusan kata kunci transaksi lokal Indonesia dan fallback machine learning / frekuensi riwayat.
21. Implementasi 3 Fitur Baru (Hapus Transaksi Bulk/Pilih, Mutasi Saldo Pemasukan Kazz, Log Sinkronisasi Database):
    - `lib/widgets/widgets.dart` & `lib/screens/transaksi_screen.dart`: Menambahkan fitur Hapus Semua Transaksi (bulk clear database lokal + cloud), Mode Seleksi Multi-Pilih (`selectable`, `isSelected`, `_selectedIds`, `_deleteSelected`), dan opsi hapus individual / long-press pada daftar transaksi.
    - `lib/services/local_db.dart` & `lib/services/api_service.dart`: Memperbaiki mutasi saldo instan di tabel `akun` SQLite lokal pada `insertTransaksiLocal` (`+` untuk pemasukan, `-` untuk pengeluaran) dan menembakkan `AppEvents.fireAkunBerubah()` saat transaksi dibuat agar saldo di menu Kazz langsung bertambah real-time.
    - `lib/screens/transaction_input_screen.dart`: Menyediakan dialog & bottom sheet pemilihan dompet tujuan saat input pemasukan ("Saldo Masuk ke Dompet Mana?") dengan integrasi pembuatan dompet baru jika daftar akun kosong.
    - `lib/services/sync_service.dart`: Menambahkan kelas `SyncLogEntry`, in-memory log buffer, method `triggerManualSync()`, serta pencatatan terperinci proses push offline queue & pull cloud database.
    - `lib/screens/more_screen.dart`: Menambahkan menu "Sinkronisasi Akun & Database" dengan bottom sheet `_SyncLogSheet` yang menampilkan indikator "Otomatis Aktif", status koneksi, jumlah antrean offline, waktu sync terakhir, daftar riwayat log sinkronisasi terperinci, dan tombol manual sync.
22. Optimasi Kecepatan & Responsivitas Setara Aplikasi Offline (Optimistic UI & Cache-First):
    - `lib/services/api_service.dart`: Terapkan non-blocking optimistic write pada `createTransaksi`, `updateTransaksi`, `deleteTransaksi`, `deleteTransaksiBatch`, `createAkun`, `updateAkunSaldo`, `deleteAkun`, `createAnggaran`, `updateAnggaran`, `deleteAnggaran`, `createGoal`, `updateProgres`, `deleteGoal`. Data ditulis langsung ke SQLite lokal (<5ms), event UI ditembakkan seketika, dan sync ke server berjalan di background (`unawaited(SyncService.instance.syncToServer(force: true))`). Form/dialog input langsung tertutup seketika tanpa tertahan latensi HTTP cloud.
    - `lib/screens/dashboard_screen.dart`: Perluas `_loadLocalCacheFirst()` untuk kalkulasi instan (pengeluaran hari ini, 7 hari terakhir, breakdown 30 hari, saldo akun) langsung dari SQLite lokal; `_onDataBerubah` memperbarui UI dalam <5ms sebelum sync background selesai.
    - `lib/screens/transaksi_screen.dart`: Cache-first rendering langsung dari SQLite lokal (`LocalDb.getTransaksi`) sehingga daftar transaksi tampil seketika saat tab dibuka tanpa spinner loading.
    - `lib/screens/kazz_screen.dart`, `lib/screens/anggaran_screen.dart`, `lib/screens/goals_screen.dart`: Cache-first rendering dari SQLite lokal sebelum fetch server di background.

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
