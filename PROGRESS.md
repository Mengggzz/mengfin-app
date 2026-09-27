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
