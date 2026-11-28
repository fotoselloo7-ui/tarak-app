# Gradle gerektirmeden APK derler (aapt2 + javac + d8 + apksigner).
#   Emulator icin :  powershell -File android\derle.ps1
#   Canli icin    :  powershell -File android\derle.ps1 -ApiAdresi "https://mobil.tarak.app/api/index.php"
# Not: Google Play'e yuklemek icin ayrica AAB ve kalici bir imza anahtari gerekir.
param(
    [string]$ApiAdresi = 'http://10.0.2.2:8812/api/index.php',
    [string]$AndroidKlasoru = 'D:\AndroidDev'
)
$ErrorActionPreference = 'Stop'
$proje = Split-Path $PSScriptRoot -Parent
$sdk = "$AndroidKlasoru\sdk"
$bt = (Get-ChildItem "$sdk\build-tools" -Directory | Sort-Object Name | Select-Object -Last 1).FullName
$jar = "$sdk\platforms\android-35\android.jar"
$env:JAVA_HOME = "$AndroidKlasoru\jdk"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
$cikti = "$PSScriptRoot\cikti"
$ara = "$cikti\ara"

function Invoke-Arac([string]$exe, [string[]]$arg) {
    & $exe @arg
    if ($LASTEXITCODE -ne 0) { throw "Basarisiz: $exe (kod $LASTEXITCODE)" }
}

if (Test-Path $ara) { Remove-Item $ara -Recurse -Force }
New-Item -ItemType Directory -Force "$ara\res", "$ara\siniflar", "$ara\dex", "$ara\assets\www" | Out-Null

# 1) Oyun dosyalari
Copy-Item "$proje\web\index.html" "$ara\assets\www\"
Copy-Item "$proje\web\assets" "$ara\assets\www\assets" -Recurse
$ayar = "window.TARAK_AYAR = { api: '$ApiAdresi', platform: 'android' };"
[IO.File]::WriteAllText("$ara\assets\www\assets\js\ayar.js", $ayar, (New-Object Text.UTF8Encoding $false))

# 2) Simgeler
Copy-Item "$PSScriptRoot\res\*" "$ara\res" -Recurse
$boylar = @{ 'mipmap-mdpi' = 48; 'mipmap-hdpi' = 72; 'mipmap-xhdpi' = 96; 'mipmap-xxhdpi' = 144; 'mipmap-xxxhdpi' = 192 }
foreach ($k in $boylar.Keys) {
    New-Item -ItemType Directory -Force "$ara\res\$k" | Out-Null
    Copy-Item "$proje\web\assets\img\ikon-$($boylar[$k]).png" "$ara\res\$k\ic_launcher.png"
}

# 3) Manifest (sifresiz http yalnizca http API adresiyle derlenirken acilir)
$acik = if ($ApiAdresi.StartsWith('http://')) { 'true' } else { 'false' }
$manifest = (Get-Content "$PSScriptRoot\AndroidManifest.xml" -Raw -Encoding UTF8).Replace('__CLEARTEXT__', $acik)
[IO.File]::WriteAllText("$ara\AndroidManifest.xml", $manifest, (New-Object Text.UTF8Encoding $false))

Invoke-Arac "$bt\aapt2.exe" @('compile', '--dir', "$ara\res", '-o', "$ara\res.zip")
Invoke-Arac "$bt\aapt2.exe" @('link', '-I', $jar, '--manifest', "$ara\AndroidManifest.xml", '-o', "$ara\temel.apk", "$ara\res.zip")

# 4) Java -> dex
$kaynaklar = Get-ChildItem "$PSScriptRoot\java" -Recurse -Filter *.java | ForEach-Object { $_.FullName }
Invoke-Arac "$env:JAVA_HOME\bin\javac.exe" (@('-encoding', 'UTF-8', '--release', '11', '-nowarn', '-cp', $jar, '-d', "$ara\siniflar") + $kaynaklar)
$siniflar = Get-ChildItem "$ara\siniflar" -Recurse -Filter *.class | ForEach-Object { $_.FullName }
Invoke-Arac "$bt\d8.bat" (@('--min-api', '24', '--lib', $jar, '--output', "$ara\dex") + $siniflar)
# Oyun dosyalari jar ile eklenir: aapt2 -A Windows'ta yollari ters egik cizgiyle yazdigi icin WebView bulamaz.
Push-Location "$ara"
Invoke-Arac "$env:JAVA_HOME\bin\jar.exe" @('uf', "$ara\temel.apk", 'assets')
Pop-Location
Push-Location "$ara\dex"
Invoke-Arac "$env:JAVA_HOME\bin\jar.exe" @('uf', "$ara\temel.apk", 'classes.dex')
Pop-Location

# 5) Hizala ve imzala (yerel test anahtari; depo disinda tutulur)
Invoke-Arac "$bt\zipalign.exe" @('-f', '-p', '4', "$ara\temel.apk", "$ara\hizali.apk")
$anahtar = "$AndroidKlasoru\debug.keystore"
if (-not (Test-Path $anahtar)) {
    Invoke-Arac "$env:JAVA_HOME\bin\keytool.exe" @('-genkeypair', '-keystore', $anahtar, '-storepass', 'android', '-keypass', 'android', '-alias', 'androiddebugkey', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000', '-dname', 'CN=Android Debug,O=Android,C=US')
}
$apk = "$cikti\tarak-kos.apk"
Invoke-Arac "$bt\apksigner.bat" @('sign', '--ks', $anahtar, '--ks-pass', 'pass:android', '--out', $apk, "$ara\hizali.apk")
Write-Output ("APK hazir: $apk ({0:N1} MB)  API: $ApiAdresi" -f ((Get-Item $apk).Length / 1MB))
