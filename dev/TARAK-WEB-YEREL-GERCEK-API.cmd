@echo off
setlocal
cd /d "%~dp0.."
title TARAK - GERCEK YEREL API WEB - 8010

REM Full-auth test mode. Does NOT access cPanel, tarak.app live API or production DB.
REM Start backend separately at http://127.0.0.1:8000 with an isolated MySQL DB.
set "TARAK_DEV_DEMO="
set "TARAK_DEV_LIVE_API="
set "TARAK_DEV_LOCAL_API=1"

where php >nul 2>&1
if errorlevel 1 (
  echo HATA: PHP PATH'te bulunamadi.
  pause
  exit /b 1
)

echo.
echo TARAK GERCEK YEREL WEB
echo Bu pencere: http://127.0.0.1:8010
echo API hedefine: http://127.0.0.1:8000
echo Backend ayri CMD'de calismali:
echo   cd /d "C:\Projeler\TARAK-APP-FINAL-KAYNAK\tarak-backend"
echo   php artisan serve --host=127.0.0.1 --port=8000
echo.
echo UYARI: Gercek yerel MySQL .env ve composer vendor olmadan giris/kayit calismaz.
echo Sunucu kapatmak icin Ctrl+C.
echo.

php -S 127.0.0.1:8010 -t tarak.app dev/local-web-router.php
pause
