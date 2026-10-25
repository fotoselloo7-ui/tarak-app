@echo off
setlocal
cd /d "%~dp0.."
title Tarak.app - Yerel Web Demo :8010

REM Yerel kaynak dosyalar, GitHub'daki derlenmis web sitesi ve sabit demo kayitlar.
REM CANLI API/CPANEL KULLANILMAZ. Laravel/Composer/MySQL gerekli degildir.
set "TARAK_DEV_LIVE_API="
set "TARAK_DEV_DEMO=1"

if not exist "tarak.app\index.html" (
  echo HATA: tarak.app\index.html bulunamadi.
  pause
  exit /b 1
)
if not exist "dev\demo-catalog.json" (
  echo HATA: Demo katalog dosyasi bulunamadi. Once git pull origin main.
  pause
  exit /b 1
)
where php >nul 2>&1
if errorlevel 1 (
  echo HATA: PHP komutu bulunamadi. PHP klasorunu PATH'e ekleyin.
  pause
  exit /b 1
)

echo.
echo TARAK.APP YEREL DEMO
echo Web: http://127.0.0.1:8010
echo Hizmet API: http://127.0.0.1:8010/api/services
echo Kategori API: http://127.0.0.1:8010/api/service-categories
echo Kaynak: Yalnizca yerel dosyalar; demo kayıtlar gercek degildir.
echo Durdur: Ctrl + C
echo.

php -S 127.0.0.1:8010 -t tarak.app dev/local-web-router.php

echo.
echo Yerel sunucu kapandi.
pause
