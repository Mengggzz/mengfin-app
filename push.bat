@echo off
setlocal enabledelayedexpansion
title Push & Commit Cashflow

cd /d "C:\Users\NAN\Desktop\cashflow"

echo ========================================================
echo          MengFin App - Auto Commit & Push
echo ========================================================
echo.

:: Cek perubahan git
git status --short > "%TEMP%\git_status_check.txt"
set /p STATUS=<"%TEMP%\git_status_check.txt"
del "%TEMP%\git_status_check.txt" 2>nul

if "!STATUS!"=="" (
    echo [INFO] Tidak ada perubahan file yang perlu di-commit.
    echo Mengecek commit lokal yang belum ter-push...
    git -c credential.helper=wincred push origin main
    echo.
    echo Selesai!
    timeout /t 3 >nul
    exit /b 0
)

:: Ambil pesan commit dari argumen atau prompt
set "MSG=%~1"
if "!MSG!"=="" (
    set /p "MSG=Masukkan pesan commit (tekan Enter untuk auto-message): "
)

if "!MSG!"=="" (
    for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "dt=%%I"
    set "TIMESTAMP=!dt:~0,4!-!dt:~4,2!-!dt:~6,2! !dt:~8,2!:!dt:~10,2!"
    set "MSG=update: !TIMESTAMP!"
)

echo.
echo [1/3] Menambahkan file ke staging...
git add -A

echo.
echo [2/3] Membuat commit: "!MSG!"...
git commit -m "!MSG!"

echo.
echo [3/3] Mendorong perubahan ke GitHub (branch: main)...
git -c credential.helper=wincred push origin main

if %ERRORLEVEL% equ 0 (
    echo.
    echo ========================================================
    echo   BERHASIL! Commit dan Push sukses terkirim ke GitHub.
    echo ========================================================
) else (
    echo.
    echo ========================================================
    echo   [ERROR] Push gagal. Periksa koneksi internet Anda.
    echo ========================================================
)

echo.
echo Jendela akan tertutup otomatis dalam 4 detik...
timeout /t 4 >nul
