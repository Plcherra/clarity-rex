# Production Flutter web release build (P6). Reads apps/mobile/.env.
param(
  [string]$BaseHref = "/app/",
  [string]$RexBackendUrl = "",
  [string]$CloudVoice = "true",
  [string]$StreamingVoice = "true",
  [switch]$Print
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$MobileDir = Join-Path $RootDir "apps\mobile"
$EnvFile = Join-Path $MobileDir ".env"

function Get-DotEnvValue([string]$Key) {
  if (-not (Test-Path $EnvFile)) { return "" }
  foreach ($line in Get-Content $EnvFile) {
    if ($line -match "^\s*#" -or $line -notmatch "=") { continue }
    $parts = $line.Split("=", 2)
    if ($parts[0].Trim() -eq $Key) {
      return $parts[1].Trim().Trim('"').Trim("'")
    }
  }
  return ""
}

$SupabaseUrl = Get-DotEnvValue "SUPABASE_URL"
$SupabaseAnonKey = Get-DotEnvValue "SUPABASE_ANON_KEY"
if (-not $RexBackendUrl) {
  $RexBackendUrl = Get-DotEnvValue "REX_BACKEND_URL"
  if (-not $RexBackendUrl) { $RexBackendUrl = "https://api.goclarity.app" }
}
$AuthRedirect = Get-DotEnvValue "SUPABASE_AUTH_REDIRECT_URL"
if (-not $AuthRedirect) { $AuthRedirect = "https://goclarity.app/app/" }

if (-not $SupabaseUrl -or -not $SupabaseAnonKey) {
  Write-Error "Missing SUPABASE_URL or SUPABASE_ANON_KEY in apps/mobile/.env"
}

$args = @(
  "build", "web", "--release",
  "--no-wasm-dry-run",
  "--base-href=$BaseHref",
  "--dart-define=SUPABASE_URL=$SupabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey",
  "--dart-define=REX_BACKEND_URL=$RexBackendUrl",
  "--dart-define=REX_CLOUD_VOICE_ENABLED=$CloudVoice",
  "--dart-define=REX_STREAMING_VOICE_ENABLED=$StreamingVoice",
  "--dart-define=SUPABASE_AUTH_REDIRECT_URL=$AuthRedirect"
)

if ($Print) {
  Write-Output "cd $MobileDir"
  Write-Output ("flutter " + ($args -join " "))
  exit 0
}

Write-Output "==> Flutter web release build (P6)"
Write-Output "    base-href=$BaseHref"
Write-Output "    output=$MobileDir\build\web"

Push-Location $MobileDir
try {
  & flutter @args
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build web failed with exit code $LASTEXITCODE"
  }

  # Stamp index.html so flutter_bootstrap can cache-bust main.dart.js on CDN edges.
  $webOut = Join-Path $MobileDir "build\web"
  $versionPath = Join-Path $webOut "version.json"
  $indexPath = Join-Path $webOut "index.html"
  $buildNumber = "0"
  if (Test-Path $versionPath) {
    $versionJson = Get-Content $versionPath -Raw | ConvertFrom-Json
    if ($versionJson.build_number) {
      $buildNumber = [string]$versionJson.build_number
    }
  }
  if (Test-Path $indexPath) {
    $indexHtml = Get-Content $indexPath -Raw
    $indexHtml = $indexHtml.Replace("BUILD_NUMBER_PLACEHOLDER", $buildNumber)
    Set-Content -Path $indexPath -Value $indexHtml -NoNewline
    Write-Output "    stamped clarity-web-build=$buildNumber"
  }
} finally {
  Pop-Location
}

Write-Output "==> Build ready. Stage with: .\scripts\flutter_web_stage_into_landing.ps1"
