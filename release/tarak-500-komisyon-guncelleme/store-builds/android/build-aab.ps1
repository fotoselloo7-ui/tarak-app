# Tarak - Google Play release AAB (Windows, tek komut)
#
#   powershell -ExecutionPolicy Bypass -File "release\tarak-500-komisyon-guncelleme\store-builds\android\build-aab.ps1"
#
# ON KOSUL (bu makinede YOK, bu yuzden AAB henuz uretilmedi):
#   mobile\android\key.properties  + mobile\android\keystore\tarak-upload-keystore.jks   (Play Console YUKLEME anahtariniz)
# Betik yeni anahtar URETMEZ. Anahtar yoksa durur; Gradle da debug imzali AAB'yi bilerek reddeder.
# Firebase (push): mobile\android\app\google-services.json varsa otomatik kullanilir, yoksa push kapali derlenir (uyari verir).
#
# Surum: mobile\pubspec.yaml "version: 1.1.0+2"  ->  versionName 1.1.0, versionCode 2.
# Play'e daha once 2 veya daha yuksek bir versionCode yuklediyseniz -BuildNumber ile ustune cikin (ornek: -BuildNumber 7).
param(
    [string]$ApiBaseUrl   = 'https://tarak.app/api',
    [string]$ReverbHost   = 'tarak.app',
    [string]$ReverbAppKey = 'hhyfpgfv2dgv95yd78kz',
    [string]$BuildName,
    [string]$BuildNumber
)
$ErrorActionPreference = 'Stop'

$root   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$mobile = Join-Path $root 'mobile'
$outDir = $PSScriptRoot

$props = Join-Path $mobile 'android\key.properties'
if (-not (Test-Path $props)) {
    throw "android\key.properties yok. Play Console yukleme anahtarinizi (keystore + key.properties) koyun: $props (sablon: android\key.properties.example). Yeni anahtar URETILMEDI."
}
$map = @{}
Get-Content $props | Where-Object { $_ -match '^\s*[^#=\s]+\s*=' } | ForEach-Object { $k, $v = $_ -split '=', 2; $map[$k.Trim()] = $v.Trim() }
foreach ($k in 'storeFile', 'storePassword', 'keyAlias', 'keyPassword') {
    if (-not $map[$k]) { throw "android\key.properties eksik deger: $k" }
}
$store = Join-Path (Join-Path $mobile 'android\app') $map['storeFile']
if (-not (Test-Path $store)) { throw "Keystore bulunamadi: $store" }

# Flutter bu makinede JDK 11'e ayarli; Android Gradle Plugin JDK 17 ister (yalniz bu komut icin).
if (-not $env:GRADLE_OPTS -and (Test-Path 'C:\Program Files\Microsoft\jdk-17*')) {
    $env:GRADLE_OPTS = '-Dorg.gradle.java.home=C:\PROGRA~1\MICROS~1\JDK-17~1.101'
}

$pubspec = Get-Content (Join-Path $mobile 'pubspec.yaml') -Raw
if ($pubspec -match '(?m)^version:\s*([0-9.]+)\+(\d+)') {
    if (-not $BuildName)   { $BuildName   = $Matches[1] }
    if (-not $BuildNumber) { $BuildNumber = $Matches[2] }
}

Push-Location $mobile
try {
    flutter pub get
    flutter build appbundle --release `
        --build-name $BuildName --build-number $BuildNumber `
        "--dart-define=API_BASE_URL=$ApiBaseUrl" `
        "--dart-define=REVERB_HOST=$ReverbHost" `
        "--dart-define=REVERB_APP_KEY=$ReverbAppKey"
    if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle basarisiz (cikis kodu $LASTEXITCODE)" }
} finally { Pop-Location }

$aab = Join-Path $mobile 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path $aab)) { throw "AAB olusmadi: $aab" }
$dest = Join-Path $outDir ("tarak-$BuildName+$BuildNumber-release.aab")
Copy-Item $aab $dest -Force

Write-Host ''
Write-Host "AAB hazir: $dest"
Write-Host ("SHA256  : " + (Get-FileHash $dest -Algorithm SHA256).Hash)
Write-Host 'Imza sahibini kontrol edin (Owner = SIZIN yukleme sertifikaniz olmali, "Android Debug" ise YUKLEMEYIN):'
Write-Host "  keytool -printcert -jarfile `"$dest`""
Write-Host 'Yukleme: Play Console > Release > Create release > AAB. Otomatik yukleme yapilmadi.'
