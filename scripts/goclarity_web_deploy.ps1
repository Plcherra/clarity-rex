# Deploy landing + Flutter PWA to Cloudflare Pages (goclarity.app/app/).
param(
  [switch]$SkipBuild,
  [string]$ProjectName = "clarity-landing",
  [string]$PublicSiteUrl = "https://goclarity.app"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$DistApp = Join-Path $RootDir "apps\web\dist\app"

if (-not $SkipBuild) {
  Write-Output "==> Step 1/3: Flutter web release build"
  & (Join-Path $RootDir "scripts\flutter_web_release_build.ps1")

  Write-Output "==> Step 2/3: Landing site build"
  & (Join-Path $RootDir "scripts\web_release_build.ps1") -PublicSiteUrl $PublicSiteUrl

  Write-Output "==> Step 3/3: Stage Flutter into landing dist"
  & (Join-Path $RootDir "scripts\flutter_web_stage_into_landing.ps1")
} else {
  Write-Output "==> Skipping builds (-SkipBuild)"
}

if (-not (Test-Path (Join-Path $DistApp "index.html"))) {
  throw "Missing apps/web/dist/app/index.html. Run without -SkipBuild first."
}

& (Join-Path $RootDir "scripts\verify_combined_web_dist.ps1") -DistDir (Join-Path $RootDir "apps\web\dist")

Write-Output "==> Deploying combined site to Cloudflare Pages"
Write-Output "    PUBLIC_SITE_URL=$PublicSiteUrl"
Write-Output "    CLOUDFLARE_PAGES_PROJECT=$ProjectName"

if (-not $env:CLOUDFLARE_API_TOKEN) {
  Write-Output "    Tip: set CLOUDFLARE_API_TOKEN (Edit Cloudflare Workers template)"
}

Push-Location $RootDir
try {
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue) {
    $global:PSNativeCommandUseErrorActionPreference = $false
  }
  npx wrangler@3 pages deploy apps/web/dist `
    --project-name $ProjectName `
    --branch main
  if ($LASTEXITCODE -ne 0) {
    throw "wrangler pages deploy failed with exit code $LASTEXITCODE"
  }
  $ErrorActionPreference = $previousEap
} finally {
  Pop-Location
}

Write-Output "==> Deploy complete"
Write-Output "    Landing: $PublicSiteUrl/"
Write-Output "    PWA app: $PublicSiteUrl/app/"
