# Generate PWA icons and favicon for apps/mobile/web from clarity_app_icon.png.
$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$src = Join-Path $RootDir "apps\mobile\assets\brand\clarity_app_icon.png"
$outDir = Join-Path $RootDir "apps\mobile\web\icons"

if (-not (Test-Path $src)) {
  Write-Error "Missing source icon at $src"
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Add-Type -AssemblyName System.Drawing

function Resize-Png([int]$size, [string]$dest) {
  $img = [System.Drawing.Image]::FromFile((Resolve-Path $src))
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($img, 0, 0, $size, $size)
  $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
  $img.Dispose()
  Write-Output "  $dest"
}

Write-Output "Generating web PWA icons from $src"
Resize-Png 32 (Join-Path $RootDir "apps\mobile\web\favicon.png")
Resize-Png 192 (Join-Path $outDir "Icon-192.png")
Resize-Png 512 (Join-Path $outDir "Icon-512.png")
Resize-Png 192 (Join-Path $outDir "Icon-maskable-192.png")
Resize-Png 512 (Join-Path $outDir "Icon-maskable-512.png")
Write-Output "Done."
