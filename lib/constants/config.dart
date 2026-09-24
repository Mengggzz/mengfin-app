// Local development:
const String kApiBaseUrl = 'http://localhost:3000/api';
// Production (uncomment untuk deploy):
// const String kApiBaseUrl = 'https://web-production-c21a6.up.railway.app/api';

// Google OAuth Client ID (dari Google Cloud Console)
// Ganti dengan Client ID kamu setelah setup di console.cloud.google.com
const String kGoogleClientId = '266649571000-80vs1ngb0cnn2vo06aoei8katfmu4lhg.apps.googleusercontent.com';

// ── Build tag aplikasi ─────────────────────────────────────────────────────
// Dipakai untuk mencocokkan dengan tag release GitHub (format vYYYYMMDD-HHMM
// yang dibuat otomatis oleh workflow CI). Di-inject saat build:
//   flutter build apk --dart-define=APP_BUILD_TAG=v20260923-1210
// Kalau kosong (build lokal / dev), pengecekan update dilewati dengan aman.
const String kAppBuildTag = String.fromEnvironment('APP_BUILD_TAG');
