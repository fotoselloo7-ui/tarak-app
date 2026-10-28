param(
    [string]$Repo = "C:\Projeler\TARAK-APP-FINAL-KAYNAK",
    [string]$Baseline = "aa7ce4b63e442c3e9411a88276c6a9a193ff2594"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path (Join-Path $Repo ".git"))) {
    throw "Git deposu bulunamadi: $Repo"
}

Set-Location $Repo

$branch = (git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0) { throw "git branch okunamadi." }

$head = (git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw "HEAD okunamadi." }

Write-Host ""
Write-Host "TARAK CANLI DEPLOY ZIP" -ForegroundColor Cyan
Write-Host "Repo   : $Repo"
Write-Host "Branch : $branch"
Write-Host "HEAD   : $head"
Write-Host ""

# Only production web/backend changes since the stable pre-integration baseline.
$changed = @(git diff --name-only "$Baseline..HEAD" -- tarak-backend tarak.app)
if ($LASTEXITCODE -ne 0) {
    throw "git diff basarisiz. Baseline commit yerelde bulunuyor mu kontrol edin: $Baseline"
}

$excludeRegex = @(
    '^tarak-backend/\.env$',
    '^tarak-backend/vendor/',
    '^tarak-backend/storage/',
    '^tarak-backend/tests/',
    '^tarak-backend/phpunit\.xml$',
    '^tarak-backend/\.phpunit',
    '^tarak-backend/database/.*\.sqlite$',
    '^tarak-backend/database/.*\.sql$'
)

$deployFiles = New-Object System.Collections.Generic.List[string]

foreach ($raw in $changed) {
    $path = ($raw -replace '\\','/').Trim()
    if (-not $path) { continue }

    $excluded = $false
    foreach ($rx in $excludeRegex) {
        if ($path -match $rx) {
            $excluded = $true
            break
        }
    }
    if ($excluded) { continue }

    $full = Join-Path $Repo ($path -replace '/', '\')
    if (Test-Path $full -PathType Leaf) {
        $deployFiles.Add($path)
    }
}

if ($deployFiles.Count -eq 0) {
    throw "Paketlenecek web/backend degisikligi bulunamadi."
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$stage = Join-Path $env:TEMP "tarak-deploy-$stamp"
$zipPath = Join-Path $Repo "TARAK-WEB-BACKEND-DEPLOY-$stamp.zip"

if (Test-Path $stage) {
    Remove-Item $stage -Recurse -Force
}
New-Item -ItemType Directory -Path $stage | Out-Null

foreach ($path in $deployFiles) {
    $src = Join-Path $Repo ($path -replace '/', '\')
    $dst = Join-Path $stage ($path -replace '/', '\')
    $dstDir = Split-Path $dst -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item $src $dst -Force
}

$notes = @"
TARAK.APP CANLI DEPLOY PAKETI
=============================

Kaynak branch : $branch
Kaynak HEAD   : $head
Baseline      : $Baseline
Olusturma     : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Dosya sayisi  : $($deployFiles.Count)

PAKET YAPISI
------------
tarak-backend/  -> mevcut backend klasorunun ustune yaz
tarak.app/      -> mevcut web klasorunun ustune yaz

BILEREK PAKETE ALINMAYANLAR
---------------------------
- tarak-backend/.env
- vendor/
- storage/
- test dosyalari
- phpunit.xml
- eski/buyuk SQL dump dosyalari
- yerel SQLite/veritabani dosyalari

ONEMLI
------
1. Canli .env dosyasinin ustune yazmayin.
2. Mevcut canli veritabanini yeniden SQL dump ile import etmeyin.
3. Veritabani degisiklikleri Laravel migration ile uygulanacak.
4. Mevcut kullanici, berber, yorum, randevu ve hizmet verilerini silmeyin.
5. ZIP'i proje kokunde acarsaniz tarak-backend ve tarak.app yollarini korur.

ZIP acildiktan SONRA terminal komutlari ayrica uygulanmalidir:
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan optimize:clear
php artisan config:cache
php artisan route:cache

Google/Apple/Maps/SMTP/SMS gercek servis anahtarlari .env veya Admin Entegrasyon Merkezi
uzerinden ayrica yapilandirilmalidir.
"@

Set-Content -Path (Join-Path $stage "DEPLOY-NOTLARI.txt") -Value $notes -Encoding UTF8
Set-Content -Path (Join-Path $stage "DEPLOY-DOSYALARI.txt") -Value ($deployFiles -join [Environment]::NewLine) -Encoding UTF8

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -CompressionLevel Optimal -Force

$zip = Get-Item $zipPath
Write-Host ""
Write-Host "HAZIR:" -ForegroundColor Green
Write-Host $zip.FullName -ForegroundColor Green
Write-Host ("Boyut: {0:N2} MB" -f ($zip.Length / 1MB))
Write-Host ("Paketlenen dosya: {0}" -f $deployFiles.Count)
Write-Host ""
Write-Host "Bu ZIP'i cPanel proje kokune yukleyip 'Extract' diyebilirsin." -ForegroundColor Yellow

Remove-Item $stage -Recurse -Force
