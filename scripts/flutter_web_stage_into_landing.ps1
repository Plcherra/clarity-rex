# Copy Flutter build/web into apps/web/dist/app for combined Cloudflare deploy.
param(
  [switch]$SkipBuildCheck
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$FlutterOut = Join-Path $RootDir "apps\mobile\build\web"
$LandingDist = Join-Path $RootDir "apps\web\dist"
$AppDest = Join-Path $LandingDist "app"

if (-not (Test-Path $FlutterOut)) {
  throw "Missing Flutter build at $FlutterOut. Run .\scripts\flutter_web_release_build.ps1 first."
}
if (-not (Test-Path $LandingDist)) {
  throw "Missing landing dist at $LandingDist. Run .\scripts\web_release_build.sh first."
}

Write-Output "==> Staging Flutter PWA into landing dist"
Write-Output "    $FlutterOut -> $AppDest"

if (Test-Path $AppDest) {
  Remove-Item -Recurse -Force $AppDest
}
New-Item -ItemType Directory -Force -Path $AppDest | Out-Null
Copy-Item -Path (Join-Path $FlutterOut "*") -Destination $AppDest -Recurse -Force

Write-Output "==> Staged at $AppDest"
