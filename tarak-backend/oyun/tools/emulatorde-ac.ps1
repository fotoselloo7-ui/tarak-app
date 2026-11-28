# Yerel sunucuyu ve Android emulatorunu acip oyunu baslatir.
$ErrorActionPreference = 'Stop'
$proje = Split-Path $PSScriptRoot -Parent
$kok = 'D:\AndroidDev'
$env:JAVA_HOME = "$kok\jdk"; $env:ANDROID_HOME = "$kok\sdk"; $env:ANDROID_SDK_ROOT = "$kok\sdk"; $env:ANDROID_AVD_HOME = "$kok\avd"
$adb = "$kok\sdk\platform-tools\adb.exe"

# 1) Sunucu (admin paneli ve skorlar icin): http://localhost:8812
if (-not (Get-NetTCPConnection -LocalPort 8812 -State Listen -ErrorAction SilentlyContinue)) {
    Start-Process 'C:\xampp\php\php.exe' -ArgumentList '-S', '127.0.0.1:8812', '-t', "`"$proje\web`"", "`"$proje\dev-router.php`"" -WindowStyle Minimized
    Write-Host 'Sunucu baslatildi: http://localhost:8812  (panel: /admin/)'
}

# 2) Emulator
if (-not (Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue)) {
    # TarakHizli: 720x1600, 2 GB RAM, dogrudan ekran karti, anlik goruntuden hizli acilis
    Write-Host 'Sanal telefon aciliyor...'
    Start-Process "$kok\sdk\emulator\emulator.exe" -ArgumentList '-avd', 'TarakHizli', '-port', '5554', '-no-boot-anim', '-gpu', 'host', '-no-audio'
}
$ErrorActionPreference = 'Continue'
$bas = Get-Date
do {
    Start-Sleep -Seconds 3
    $hazir = ((& $adb shell getprop sys.boot_completed 2>$null) -join '').Trim() -eq '1'
} while (-not $hazir -and ((Get-Date) - $bas).TotalSeconds -lt 420)
if (-not $hazir) { Write-Host 'Emulator acilamadi.'; exit 1 }

# 3) Oyunu yukle (gerekirse) ve ac
if (-not ((& $adb shell pm list packages app.tarak.oyun) -match 'app.tarak.oyun')) {
    $apk = "$proje\android\cikti\tarak-kos.apk"
    if (-not (Test-Path $apk)) { & "$proje\android\derle.ps1" }
    & $adb install -r $apk
}
& $adb shell am start -n app.tarak.oyun/.MainActivity | Out-Null
Write-Host 'Oyun acildi. Iyi eglenceler!'
