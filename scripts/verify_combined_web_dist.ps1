# Fail if dist is landing-only or missing Flutter assets (Start on web hangs or shows marketing HTML).
param(
  [Parameter(Mandatory = $true)]
  [string]$DistDir
)

$ErrorActionPreference = "Stop"
$AppDir = Join-Path $DistDir "app"
$AppIndex = Join-Path $AppDir "index.html"
$RootIndex = Join-Path $DistDir "index.html"

$RequiredFiles = @(
  "index.html",
  "main.dart.js",
  "flutter_bootstrap.js",
  "flutter_service_worker.js",
  "passkeys_bundle.js",
  "manifest.json"
)

if (-not (Test-Path $AppIndex)) {
  throw "Missing Flutter PWA at $AppIndex. Run .\scripts\goclarity_web_deploy.ps1 (full build + stage), not landing-only."
}

$appHtml = Get-Content $AppIndex -Raw
if ($appHtml -notmatch 'flutter_bootstrap') {
  throw "$AppIndex is not the Flutter web app. Stage Flutter into apps/web/dist/app/ before deploy."
}

if ((Test-Path $RootIndex) -and ((Get-FileHash $RootIndex).Hash -eq (Get-FileHash $AppIndex).Hash)) {
  throw "$AppIndex is identical to the landing page index.html. Stage the Flutter build before deploy."
}

foreach ($rel in $RequiredFiles) {
  $path = Join-Path $AppDir $rel
  if (-not (Test-Path $path)) {
    throw "Missing Flutter asset: $path. Run flutter build + stage scripts first."
  }
}

$passkeysHead = (Get-Content (Join-Path $AppDir "passkeys_bundle.js") -TotalCount 1) -join ''
if ($passkeysHead -match '<!DOCTYPE html>') {
  throw "$(Join-Path $AppDir 'passkeys_bundle.js') looks like HTML, not JavaScript."
}

Write-Output "==> Verified combined dist (landing + Flutter PWA at /app/)"
