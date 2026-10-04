# MengFin App

Aplikasi keuangan personal berbasis Flutter yang terhubung ke backend Node.js.

## Cara Menjalankan

### 1. Pastikan Backend Berjalan
```bash
cd ../backend
npm run dev
# Backend berjalan di http://localhost:3000/api
```

### 2. Sesuaikan IP (untuk perangkat fisik)
Edit `lib/constants/config.dart`:
```dart
// Android emulator: gunakan 10.0.2.2
const String kApiBaseUrl = 'http://10.0.2.2:3000/api';

// Perangkat fisik: ganti dengan IP mesin kamu
const String kApiBaseUrl = 'http://192.168.1.X:3000/api';
```
Cari IP dengan: `ipconfig` (cari IPv4 Address)

### 3. Jalankan App
```bash
cd flutter_app
flutter pub get          # install dependencies
flutter run              # jalankan di emulator/device
```

## Struktur Folder
```
lib/
  main.dart              ← Entry point + bottom navigation
  constants/
    app_colors.dart      ← Design tokens (warna, gradient)
    config.dart          ← API base URL
    utils.dart           ← Format rupiah, tanggal, kategori
  models/
    models.dart          ← Semua data class
  services/
    api_service.dart     ← HTTP client untuk semua endpoint
  screens/
    dashboard_screen.dart
    transaksi_screen.dart
    anggaran_screen.dart
    goals_screen.dart
    ai_screen.dart
  widgets/
    widgets.dart         ← GlassCard, CurrencyText, ProgressBar, dll
```

## Fitur
- 📊 **Dashboard** — Saldo total, health score, prediksi akhir bulan
- 💸 **Transaksi** — Catat & hapus transaksi, filter masuk/keluar
- 💰 **Anggaran** — Budget per kategori dengan progress bar
- 🏆 **Goals** — Target tabungan dengan circular progress
- 🤖 **AI Chat** — Chat dengan MengFin AI, catat transaksi via chat
