# Shared Cloudflare Pages deploy via wrangler (Windows).
# Wrangler 4+ requires Node 22; pin v3 for typical Node 18/20 installs.
param(
  [string]$DistDir = "",
  [string]$ProjectName = "clarity-landing",
  [string]$Branch = "main",
  [string]$WranglerVersion = "3"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
if (-not $DistDir) {
  $DistDir = Join-Path $RootDir "apps\web\dist"
}

$distIndex = Join-Path $DistDir "index.html"
if (-not (Test-Path $distIndex)) {
  throw "Missing $distIndex. Build the site first."
}

& (Join-Path $RootDir "scripts\verify_combined_web_dist.ps1") -DistDir $DistDir

Write-Output "==> Cloudflare Pages deploy"
Write-Output "    wrangler@$WranglerVersion"
Write-Output "    dist=$DistDir"
Write-Output "    project=$ProjectName"
Write-Output "    branch=$Branch"
Write-Output "    First time? npx wrangler@$WranglerVersion login"
Write-Output "    Or set CLOUDFLARE_API_TOKEN (see docs/flutter-web/CLOUDFLARE_DEPLOY.md)"

Push-Location $RootDir
try {
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue) {
    $global:PSNativeCommandUseErrorActionPreference = $false
  }
  npx --yes "wrangler@$WranglerVersion" pages deploy $DistDir `
    --project-name $ProjectName `
    --branch $Branch
  if ($LASTEXITCODE -ne 0) {
    throw "wrangler pages deploy failed with exit code $LASTEXITCODE"
  }
  $ErrorActionPreference = $previousEap
} finally {
  Pop-Location
}
