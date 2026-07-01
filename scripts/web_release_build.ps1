# Build Astro landing site (apps/web/dist).
param(
  [string]$PublicSiteUrl = "https://goclarity.app"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$WebDir = Join-Path $RootDir "apps\web"

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Error "npm is not installed."
}

Write-Output "==> Building Clarity landing site"
Write-Output "    PUBLIC_SITE_URL=$PublicSiteUrl"

Push-Location $WebDir
try {
  if (Test-Path "package-lock.json") {
    npm ci 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "npm ci failed with exit code $LASTEXITCODE" }
  } else {
    npm install 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "npm install failed with exit code $LASTEXITCODE" }
  }
  $env:PUBLIC_SITE_URL = $PublicSiteUrl
  npm run build 2>&1 | Out-Host
  if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE" }
} finally {
  Pop-Location
}

Write-Output "==> Web release build ready at $WebDir\dist"
