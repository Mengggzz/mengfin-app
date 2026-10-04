@echo off
chcp 65001 > nul
title MengFin - Local Server
cd /d "%~dp0"

set "CHROME=C:\Program Files\Google\Chrome\Application\chrome.exe"

echo.
echo  ==============================================
echo    MengFin - Run Lokal (Backend + Flutter Web)
echo  ==============================================
echo.

echo [0/4] Memastikan dependencies terpasang...
if not exist "backend\node_modules" (
    echo     node_modules belum ada, menjalankan npm install...
    pushd backend
    call npm install
    popd
)

echo [1/4] Menjalankan backend (port 3000)...
start "MengFin-Backend" /D "%~dp0backend" cmd /k "npm start"

echo [2/4] Menjalankan Flutter Web (port 8080)...
start "MengFin-Flutter" /D "%~dp0" cmd /k "flutter run -d web-server --web-port 8080"

echo.
echo Menunggu server siap (90 detik untuk compile pertama kali)...
echo Jangan tutup window terminal ini sampai browser sudah terbuka.
echo.

REM Health check: tunggu sampai port 8080 aktif
set "COUNTER=0"
:WAIT_LOOP
if %COUNTER% lss 90 (
    echo [Progress] Detik ke-%COUNTER%... (Flutter compile berjalan)
    timeout /t 1 /nobreak > nul
    
    REM Cek apakah port 8080 sudah aktif
    netstat -ano | find ":8080" | find "LISTEN" > nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo.
        echo [3/4] Flutter siap! Membuka Chrome...
        goto OPEN_BROWSER
    )
    
    set /a COUNTER=%COUNTER%+1
    goto WAIT_LOOP
)

:OPEN_BROWSER
REM Buka Chrome
if exist "%CHROME%" (
    start "" "%CHROME%" --no-first-run --no-default-browser-check "http://localhost:8080"
) else (
    start "" "http://localhost:8080"
)

echo [4/4] Selesai!
echo.
echo  ==============================================
echo    Backend : http://localhost:3000
echo    Flutter : http://localhost:8080
echo  ==============================================
echo.
echo  Window "MengFin-Backend" dan "MengFin-Flutter" berjalan terpisah.
echo  Tutup dua window itu kalau mau stop server.
echo.
echo  Terminal ini akan tetap terbuka untuk monitoring.
echo  Ketik "exit" kalau mau tutup.
pause > nul
