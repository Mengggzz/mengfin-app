# Setup Flutter SDK setelah download selesai
# Jalankan script ini dari folder cashflow/flutter_app

$flutterZip = "$env:USERPROFILE\flutter_sdk.zip"
$flutterDir = "C:\flutter"

Write-Host "=== MengFin Flutter Setup ===" -ForegroundColor Cyan

# 1. Cek apakah zip ada
if (-not (Test-Path $flutterZip)) {
    Write-Host "ERROR: flutter_sdk.zip tidak ditemukan di $flutterZip" -ForegroundColor Red
    Write-Host "Download dulu dari: https://docs.flutter.dev/get-started/install/windows"
    exit 1
}

# 2. Ekstrak Flutter
Write-Host "Mengekstrak Flutter SDK ke C:\flutter ..." -ForegroundColor Yellow
if (-not (Test-Path $flutterDir)) {
    Expand-Archive -Path $flutterZip -DestinationPath "C:\" -Force
    Write-Host "Ekstrak selesai!" -ForegroundColor Green
} else {
    Write-Host "Flutter sudah ada di $flutterDir, skip ekstrak." -ForegroundColor Green
}

# 3. Tambah Flutter ke PATH sesi ini
$env:PATH = "C:\flutter\bin;$env:PATH"

# 4. Verifikasi
Write-Host "Verifikasi Flutter..." -ForegroundColor Yellow
flutter --version

# 5. flutter pub get
Write-Host "`nInstall dependencies Flutter..." -ForegroundColor Yellow
Set-Location $PSScriptRoot
flutter pub get

# 6. flutter doctor
Write-Host "`nCek environment (flutter doctor)..." -ForegroundColor Yellow
flutter doctor

Write-Host "`n=== Setup Selesai! ===" -ForegroundColor Green
Write-Host "Untuk menjalankan app:"
Write-Host "  flutter run" -ForegroundColor Cyan
Write-Host "`nPastikan backend berjalan dulu:"
Write-Host "  cd ../backend && npm run dev" -ForegroundColor Cyan
