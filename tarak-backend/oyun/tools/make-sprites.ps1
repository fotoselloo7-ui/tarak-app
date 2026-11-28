# Maskot sprite'larini orijinal gorselden keser ve hikaye fotograflarini kucultur.
# Kullanim: powershell -File tools\make-sprites.ps1 -Kaynak "C:\...\Downloads"
param([string]$Kaynak = "$env:USERPROFILE\Downloads")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$cikti = Join-Path $PSScriptRoot '..\web\assets\img'
New-Item -ItemType Directory -Force $cikti | Out-Null
$cikti = (Resolve-Path $cikti).Path

function Save-Cutout($img, [double[]]$pts, [double]$ox, [double]$oy, [double]$zoom, [string]$ad) {
    $list = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
    for ($i = 0; $i -lt $pts.Length; $i += 2) {
        $list.Add((New-Object System.Drawing.PointF ([single]($pts[$i] / $zoom + $ox)), ([single]($pts[$i+1] / $zoom + $oy))))
    }
    $minX = [math]::Floor(($list | ForEach-Object { $_.X } | Measure-Object -Minimum).Minimum) - 2
    $minY = [math]::Floor(($list | ForEach-Object { $_.Y } | Measure-Object -Minimum).Minimum) - 2
    $maxX = [math]::Ceiling(($list | ForEach-Object { $_.X } | Measure-Object -Maximum).Maximum) + 2
    $maxY = [math]::Ceiling(($list | ForEach-Object { $_.Y } | Measure-Object -Maximum).Maximum) + 2
    $w = [int]($maxX - $minX); $h = [int]($maxY - $minY)
    $local = $list | ForEach-Object { New-Object System.Drawing.PointF ([single]($_.X - $minX)), ([single]($_.Y - $minY)) }

    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $doku = New-Object System.Drawing.TextureBrush $img
    $doku.TranslateTransform([single](-$minX), [single](-$minY))
    $yol = New-Object System.Drawing.Drawing2D.GraphicsPath
    $yol.AddClosedCurve([System.Drawing.PointF[]]$local, [single]0.25)
    $g.FillPath($doku, $yol)
    $g.Dispose(); $doku.Dispose()
    $bmp.Save("$cikti\$ad.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "$ad.png ${w}x${h} (kaynak x=$minX y=$minY)"
}

$yuruyen = [System.Drawing.Image]::FromFile("$Kaynak\ChatGPT Görseli 26 Kas 2026 15_22_47-2.png")

# Govde (koordinatlar 2x buyutulmus kirpimdan; orijin 200,230)
$govde = 355,1247, 300,1225, 255,1190, 222,1140, 195,1075, 170,990, 150,920, 135,850, 120,760, 108,660, 100,560, 96,470, 95,380, 100,330, 112,275, 135,225, 165,185, 200,155, 245,125, 300,98, 360,80, 420,73, 470,80, 515,96, 550,122, 585,165, 610,205, 625,250, 631,300, 631,380, 628,425, 630,461, 660,451, 700,434, 750,418, 800,415, 870,418, 915,426, 945,446, 959,475, 959,505, 945,535, 900,605, 850,680, 800,750, 769,829, 800,832, 829,846, 849,871, 900,955, 950,1050, 977,1110, 983,1140, 975,1170, 954,1195, 920,1208, 850,1220, 770,1229, 720,1228, 692,1217, 680,1205, 660,1221, 625,1235, 570,1247, 500,1252, 430,1252
Save-Cutout $yuruyen $govde 200 230 2 'k-govde'

# Eldiven (5x kirpim; orijin 660,665)
$eldiven = 77,290, 81,240, 96,196, 126,151, 166,107, 216,77, 260,70, 305,87, 339,117, 359,157, 400,170, 450,192, 504,227, 558,276, 598,331, 618,390, 625,450, 623,500, 603,558, 569,608, 519,648, 460,675, 405,677, 361,662, 322,628, 292,588, 272,540, 268,490, 282,455, 245,440, 215,414, 190,406, 150,408, 112,388, 87,350
Save-Cutout $yuruyen $eldiven 660 665 5 'k-eldiven'

# Ayakkabi (4x kirpim; orijin 420,1070)
$ayakkabi = 107,152, 127,127, 166,102, 230,80, 300,65, 368,63, 417,78, 442,107, 472,118, 492,151, 499,200, 492,238, 477,260, 498,286, 518,331, 548,376, 588,421, 638,461, 687,511, 712,565, 737,601, 752,641, 761,689, 747,718, 708,747, 639,781, 559,811, 470,831, 380,841, 300,856, 222,871, 188,866, 178,852, 138,841, 124,808, 119,765, 136,757, 123,720, 104,640, 96,560, 94,470, 90,390, 64,368, 44,330, 32,280, 39,242, 68,208, 107,187
Save-Cutout $yuruyen $ayakkabi 420 1070 4 'k-ayakkabi'
$yuruyen.Dispose()

# Hikaye fotograflari -> JPG (genislik 720)
$jpgKodlayici = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ayar = New-Object System.Drawing.Imaging.EncoderParameters 1
$ayar.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]80)
$fotolar = @{
    'foto-bildirim'  = 'ChatGPT Görseli 26 Kas 2026 15_34_25.png'
    'foto-yolda'     = 'Ormanda Neşeli K Maskotu Sürüşte-2.png'
    'foto-yuruyus'   = 'ChatGPT Görseli 26 Kas 2026 15_22_47-2.png'
    'foto-musteri'   = 'Ormanın Kalbinde Aslan ve Telefon.png'
    'foto-hazirlik'  = 'ChatGPT Görseli 26 Kas 2026 15_22_48-3.png'
    'foto-tiras'     = 'ChatGPT Görseli 26 Kas 2026 15_22_50-5.png'
    'foto-sonuc'     = 'ChatGPT Görseli 26 Kas 2026 15_22_51-6.png'
    'foto-sofor'     = 'Neşeli Maskotla Yolculuk-1.png'
}
foreach ($ad in $fotolar.Keys) {
    $kaynakDosya = Join-Path $Kaynak $fotolar[$ad]
    if (-not (Test-Path -LiteralPath $kaynakDosya)) { Write-Output "ATLANDI: $ad"; continue }
    $im = [System.Drawing.Image]::FromFile($kaynakDosya)
    $w = 720; $h = [int]($im.Height * 720 / $im.Width)
    $b = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($im, 0, 0, $w, $h)
    $g.Dispose()
    $b.Save("$cikti\$ad.jpg", $jpgKodlayici, $ayar)
    $b.Dispose(); $im.Dispose()
}
Write-Output "Tamam -> $cikti"
