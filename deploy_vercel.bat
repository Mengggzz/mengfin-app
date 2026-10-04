@echo off
echo ===================================
echo  MengFin - Build dan Deploy Vercel
echo ===================================
echo.

cd /d C:\Users\NAN\Desktop\cashflow\flutter_app

echo [1/3] Flutter build web...
call flutter build web --release
if errorlevel 1 (
    echo GAGAL build Flutter!
    pause
    exit /b 1
)

echo.
echo [2/3] Masuk ke folder build\web...
cd build\web

echo.
echo [3/3] Deploy ke Vercel...
call vercel --prod --yes

echo.
echo ===================================
echo  SELESAI! Cek https://mengfin.vercel.app
echo ===================================
pause
