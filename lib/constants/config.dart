// ── Base URL API & Mode Operasi ───────────────────────────────────────────
// Tanpa --dart-define=API_BASE_URL (atau bernilai 'local') -> aplikasi berjalan
// 100% lokal offline-first (kLocalMode == true).
// Backend diparkir dan tidak lagi default ke server Railway yang sudah mati.
const String _kApiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');
const bool kLocalMode = _kApiBaseUrlOverride == '' || _kApiBaseUrlOverride == 'local';
const String kApiBaseUrl = kLocalMode
    ? ''
    : _kApiBaseUrlOverride;

// Google OAuth Client ID (dari Google Cloud Console)
// Ganti dengan Client ID kamu setelah setup di console.cloud.google.com
const String kGoogleClientId = '266649571000-80vs1ngb0cnn2vo06aoei8katfmu4lhg.apps.googleusercontent.com';

// ── Build tag aplikasi ─────────────────────────────────────────────────────
// Dipakai untuk mencocokkan dengan tag release GitHub (format vYYYYMMDD-HHMM
// yang dibuat otomatis oleh workflow CI). Di-inject saat build:
//   flutter build apk --dart-define=APP_BUILD_TAG=v20260923-1210
// Kalau kosong (build lokal / dev), pengecekan update dilewati dengan aman.
const String kAppBuildTag = String.fromEnvironment('APP_BUILD_TAG');

// ── Repo GitHub untuk notifikasi update ────────────────────────────────────
// Jalur cadangan: kalau backend belum punya endpoint /update/check (server
// produksi masih versi lama), app query GitHub Releases langsung. Repo ini
// publik, jadi tidak perlu token.
const String kGithubOwner = 'Mengggzz';
const String kGithubRepo  = 'mengfin-app';
