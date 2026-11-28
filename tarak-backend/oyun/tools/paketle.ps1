# Subdomain'e yuklenecek temiz zip'i hazirlar (yerel veritabani ve test sifresi PAKETE GIRMEZ).
$ErrorActionPreference = 'Stop'
$proje = Split-Path $PSScriptRoot -Parent
$gecici = Join-Path $env:TEMP ('tarak-paket-' + [guid]::NewGuid().ToString('N'))
$dist = "$proje\dist"
New-Item -ItemType Directory -Force $gecici, $dist | Out-Null
Get-ChildItem "$proje\web" -Force | Where-Object { $_.Name -ne 'data' } | Copy-Item -Destination $gecici -Recurse -Force
New-Item -ItemType Directory -Force "$gecici\data" | Out-Null
Copy-Item "$proje\web\data\.htaccess" "$gecici\data\"

# Compress-Archive Windows'ta ters egik cizgi yazabildigi icin girdiler tek tek eklenir.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = "$dist\tarak-oyun-subdomain.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
$arsiv = [IO.Compression.ZipFile]::Open($zip, 'Create')
Get-ChildItem $gecici -Recurse -File -Force | ForEach-Object {
    $ad = $_.FullName.Substring($gecici.Length + 1).Replace('\', '/')
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($arsiv, $_.FullName, $ad) | Out-Null
}
$arsiv.Dispose()
Remove-Item $gecici -Recurse -Force
Write-Output ("Paket hazir: $zip ({0:N1} MB)" -f ((Get-Item $zip).Length / 1MB))
