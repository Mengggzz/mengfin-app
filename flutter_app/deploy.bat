@echo off
title MengFin - Build & Deploy to Vercel
color 0A

echo.
echo  =============================================
echo   MengFin - Build and Deploy to Vercel
echo  =============================================
echo.

echo [1/2] Building Flutter Web...
echo.
call flutter build web --release

if %errorlevel% neq 0 (
    echo.
    echo  ERROR: Flutter build gagal!
    pause
    exit /b 1
)

echo.
echo [2/2] Deploying to Vercel...
echo.
cd build\web
call vercel --prod --yes

if %errorlevel% neq 0 (
    echo.
    echo  ERROR: Deploy ke Vercel gagal!
    cd ..\..
    pause
    exit /b 1
)

cd ..\..
echo.
echo  =============================================
echo   BERHASIL! App sudah live di Vercel!
echo   Buka: https://mengfin.vercel.app
echo  =============================================
echo.
pause
