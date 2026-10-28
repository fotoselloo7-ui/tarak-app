param([ValidateRange(1, 65535)][int]$Port = 8010, [switch]$SeedPreview)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$backend = Join-Path $projectRoot 'tarak-backend'
$web = Join-Path $projectRoot 'tarak.app'
$router = Join-Path $PSScriptRoot 'local-router.php'
$envFile = Join-Path $backend '.env'
$dbFile = Join-Path $backend 'database/database.sqlite'

if (-not (Get-Command php -ErrorAction SilentlyContinue)) {
    throw 'PHP 8.2+ is required. Install PHP with pdo_sqlite, then run this script again.'
}

# Windows allows two PHP development servers to bind the same port with
# SO_REUSEADDR. Refuse an occupied port so requests cannot hit another project.
$probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$probe.ExclusiveAddressUse = $true
try { $probe.Start() }
catch { throw "Port $Port is already in use. Stop that local server or run this script with -Port 18810." }
finally { $probe.Stop() }

if (-not (Test-Path (Join-Path $backend 'vendor/autoload.php'))) {
    $composer = Get-Command composer -ErrorAction SilentlyContinue
    if ($composer) {
        & $composer.Source install --working-dir=$backend --no-interaction --prefer-dist --no-progress
    } else {
        $toolsDir = Join-Path $projectRoot '.tools'
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
        $phar = Join-Path $toolsDir 'composer.phar'
        if (-not (Test-Path $phar)) {
            Write-Host 'Downloading Composer from getcomposer.org...'
            Invoke-WebRequest -Uri 'https://getcomposer.org/composer-stable.phar' -OutFile $phar
        }
        Push-Location $backend
        try { & php $phar install --no-interaction --prefer-dist --no-progress }
        finally { Pop-Location }
    }
    if ($LASTEXITCODE -ne 0) { throw 'Composer install failed.' }
}

$newEnvironment = -not (Test-Path $envFile)
if ($newEnvironment) {
    $config = Get-Content (Join-Path $backend '.env.example') -Raw
    $config = $config -replace '(?m)^APP_NAME=.*$', 'APP_NAME=Tarak'
    $config = $config -replace '(?m)^APP_URL=.*$', "APP_URL=http://localhost:$Port"
    $config = $config -replace '(?m)^FRONTEND_URL=.*$', "FRONTEND_URL=http://localhost:$Port,http://127.0.0.1:$Port"
    $config = $config -replace '(?m)^SANCTUM_STATEFUL_DOMAINS=.*$', "SANCTUM_STATEFUL_DOMAINS=localhost:$Port,127.0.0.1:$Port"
    $config = $config -replace '(?m)^DB_CONNECTION=.*$', 'DB_CONNECTION=sqlite'
    $config = $config -replace '(?m)^DB_DATABASE=.*$', 'DB_DATABASE=database/database.sqlite'
    [System.IO.File]::WriteAllText($envFile, $config)
    Push-Location $backend
    try { & php artisan key:generate --no-ansi }
    finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw 'Laravel APP_KEY generation failed.' }
}

$connection = & php (Join-Path $PSScriptRoot 'assert-local-database.php')
if ($LASTEXITCODE -ne 0) { throw 'Local database safety check failed.' }
if ($SeedPreview -and $connection -ne 'sqlite') { throw 'Preview seeding is only allowed on isolated SQLite.' }

# These values also override stale process-level variables. No local request
# or migration may silently follow a production connection URL/config cache.
foreach ($key in @('DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD', 'DB_SOCKET', 'APP_KEY')) {
    Remove-Item -LiteralPath "Env:$key" -ErrorAction SilentlyContinue
}
$env:APP_ENV = 'local'
$env:APP_URL = "http://localhost:$Port"
$env:FRONTEND_URL = "http://localhost:$Port,http://127.0.0.1:$Port"
$env:SANCTUM_STATEFUL_DOMAINS = "localhost:$Port,127.0.0.1:$Port"
$env:DB_CONNECTION = $connection
if ($connection -eq 'sqlite') { $env:DB_DATABASE = $dbFile }
$env:DB_URL = ''

$newDatabase = -not (Test-Path $dbFile) -or (Get-Item $dbFile -ErrorAction SilentlyContinue).Length -eq 0
if ($connection -eq 'sqlite' -and -not (Test-Path $dbFile)) { New-Item -ItemType File -Path $dbFile | Out-Null }
Push-Location $backend
try {
    & php artisan config:clear --no-ansi
    if ($LASTEXITCODE -ne 0) { throw 'Laravel config cache could not be cleared.' }
    & php artisan migrate --force --no-ansi
    if ($LASTEXITCODE -ne 0) { throw 'Laravel migrations failed.' }
    if ($connection -eq 'sqlite' -and $newDatabase) {
        & php artisan db:seed --class=ServiceCatalogSeeder --force --no-ansi
        if ($LASTEXITCODE -ne 0) { throw 'Local service catalog setup failed.' }
    }
    if ($SeedPreview) {
        & php artisan local:seed-preview --no-ansi
        if ($LASTEXITCODE -ne 0) { throw 'Local catalog/demo setup failed.' }
    }
} finally { Pop-Location }

Write-Host "Tarak local web + Laravel API: http://localhost:$Port"
Write-Host 'Press Ctrl+C to stop.'
& php -S "127.0.0.1:$Port" -t $web $router
