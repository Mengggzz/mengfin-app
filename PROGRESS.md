# Lanjutan pekerjaan cashflow — status per 27 Sep 2026

Berkas ini catatan proses supaya bisa dilanjutkan. Hapus kalau sudah selesai.

## Permintaan asal
"Beberapa fitur belum berjalan functionnya — analisa dan perbaiki."
Cara kerja yang dipilih pengguna: kerjakan satu per satu, dicek dulu tiap selesai.

## Daftar fitur mati yang ditemukan (dengan bukti)
1. `lib/screens/more_screen.dart:96` — tile "Tentang MengFin" `onTap: () {}`.
2. `lib/widgets/widgets.dart:652` — `_opGroup()` `onTap: () {}`; `×` dan `÷` cuma `Text`.
3. `lib/screens/transaction_input_screen.dart:351` — `onEquals: () {}`.
4. `lib/screens/settings_screen.dart` — toggle/kata kunci/dompet hanya state lokal;
   tombol "Simpan" cuma `Navigator.pop`. Chevron "Aplikasi yang dipantau" tanpa aksi.
5. `lib/services/api_service.dart` — tidak ada `updateTransaksi` (backend punya `PUT /transaksi/:id`).
6. `anggaran_screen.dart:45`, `goals_screen.dart:39`, `transaksi_screen.dart:144` — hapus tanpa try/catch.
7. `lib/screens/transaksi_screen.dart:227` — `_filterBtn('Buka filter', Icons.tune, () {})`.
8. Auto-catat notifikasi: tidak ada plugin sama sekali di pubspec.

## Selesai dan sudah dipush (commit 79ea311 di origin/main)
- `lib/services/amount_expression.dart` (baru) + `test/amount_expression_test.dart` (13 tes).
  Bug: `25 + 10` dulu tersimpan **2510** (karena `_parseAmount` membuang non-digit). Sekarang **35**.
- `more_screen.dart` — "Tentang MengFin" → sheet: versi dari `PackageInfo` + tombol "Cek pembaruan"
  (`UpdateFlow.run(force: true)`).
- `widgets.dart` — `×`/`÷` jadi tombol; `onEquals` jadi `required`; numpad 5 baris.
- `update_dialog.dart` — `UpdateFlow.run(..., force:)`.
- `test/dead_controls_test.dart` (baru, 5 tes).
- Bonus: dua RenderFlex overflow di 360dp diperbaiki (chip dompet 70px, Need/Want/Saving 12px).
- Verifikasi: `flutter analyze` 0 error, `flutter test` 53 lulus.

## Sedang dikerjakan (BELUM dipush, belum masuk UI)
- `lib/services/notif_parser.dart` (baru) + `test/notif_parser_test.dart` — **18 tes lulus**.
  Murni, tanpa plugin, jadi bisa diuji tanpa HP. Tiga bug ketemu lewat tes dan diperbaiki:
  regex membaca grup yang salah (RangeError), notifikasi promo lolos sebagai transaksi,
  satuan terpisah spasi ("2 juta") tidak terbaca.
- `lib/services/app_prefs.dart` (baru) + `test/app_prefs_test.dart` — **6 tes lulus**.
  Menyimpan: dompet utama, dompet tampil, toggle notif, kata kunci, aplikasi dipantau.
- `lib/services/notif_service.dart` (baru) — pembaca notifikasi. Plugin
  `notification_listener_service ^1.0.0` sudah ditambahkan ke `pubspec.yaml`.
  **Belum pernah dijalankan** (tidak bisa di web; plugin hanya jalan di Android).
- `android/app/src/main/AndroidManifest.xml` — blok `<service>` NotificationListener sudah ditambahkan.
- `flutter analyze` 0 error setelah semua di atas.

## Sisa pekerjaan
1. **Item 2 — pengaturan benar-benar dipakai:**
   - `settings_screen.dart`: hapus `AppPrefs` belum diimpor/dipakai; simpan saat "Simpan" ditekan;
     chevron "Aplikasi yang dipantau" → pemilih aplikasi; toggle memanggil `NotifService.terapkanPreferensi()`.
   - `main.dart`: `await AppPrefs.instance.init()` dan `NotifService.instance.muatPaketSendiri()`.
   - Beranda: `d.saldoTotal` diganti saldo dompet terpilih (ambil dari `ApiService.getAkunList()`).
   - `transaction_input_screen.dart`: chip dompet dari daftar akun asli + kirim `akun_id`.
2. **Item 3 — edit transaksi:**
   - `ApiService.updateTransaksi(id, body)` → `PUT /transaksi/$id`, update lokal + antrean kalau offline.
   - Dialog edit saat baris transaksi diketuk (transaksi/beranda/kalender).
   - try/catch + pesan jelas di `_delete` anggaran/goals/transaksi.
3. **Item 4 — uji di HP:** `flutter build apk` lokal GAGAL di mesin ini (JDK/Gradle);
   verifikasi lewat `flutter test` + `flutter build web --release`, APK dibangun CI
   (repo Mengggzz/mengfin-app, branch main).
4. Perbaikan lain yang sengaja belum dikerjakan (perlu keputusan pengguna):
   - `transaction_input_screen.dart` — ikon `auto_fix_high` + klaim "Otomatis kategorikan dari
     transaksi terakhir" tanpa aksi. Diimplementasikan atau teksnya dibuang?
   - `settings_screen.dart` — banner menyebut "Scan All memerlukan Premium" padahal tidak ada
     sistem premium sama sekali.
   - 404 `/update/check` di server produksi itu normal (endpoint app ada, versi produksi lama);
     app sudah query GitHub Releases langsung, jadi bukan bug.

## Catatan mesin
- Backend lokal: `cd backend && node src/index.js` (port 3000). Saat sesi ini belum dinyalakan.
- Flutter web: `flutter run -d chrome --web-port 8080`.
