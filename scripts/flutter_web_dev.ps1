# Flutter web dev helper for Windows (reads apps/mobile/.env).
param(
  # Use web-server when Chrome debug tooling fails on Windows (open URL manually).
  [ValidateSet("chrome", "edge", "web-server")]
  [string]$Device = "web-server",
  [int]$WebPort = 8081,
  [string]$RexBackendUrl = "",
  [switch]$Release,
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
$CloudVoice = Get-DotEnvValue "REX_CLOUD_VOICE_ENABLED"
if (-not $CloudVoice) { $CloudVoice = "true" }
$StreamingVoice = Get-DotEnvValue "REX_STREAMING_VOICE_ENABLED"
if (-not $StreamingVoice) { $StreamingVoice = "true" }
$AuthRedirect = Get-DotEnvValue "SUPABASE_AUTH_REDIRECT_URL"
if (-not $AuthRedirect) { $AuthRedirect = "https://goclarity.app/auth/confirmed/" }

if (-not $SupabaseUrl -or -not $SupabaseAnonKey) {
  Write-Error "Missing SUPABASE_URL or SUPABASE_ANON_KEY in apps/mobile/.env"
}

$args = @(
  "run", "-d", $Device,
  "--web-port=$WebPort",
  "--web-hostname=localhost",
  "--dart-define=SUPABASE_URL=$SupabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey",
  "--dart-define=REX_BACKEND_URL=$RexBackendUrl",
  "--dart-define=REX_CLOUD_VOICE_ENABLED=$CloudVoice",
  "--dart-define=REX_STREAMING_VOICE_ENABLED=$StreamingVoice",
  "--dart-define=SUPABASE_AUTH_REDIRECT_URL=$AuthRedirect"
)
if ($Release) {
  $args += "--release"
}

if ($Print) {
  Write-Output "cd $MobileDir"
  Write-Output ("flutter " + ($args -join " "))
  exit 0
}

if ($Device -eq "web-server") {
  Write-Output "==> Starting Flutter web dev server (no Chrome debugger)"
  Write-Output "    Open: http://localhost:$WebPort"
  Write-Output "    Voice testing needs localhost (mic works on http://localhost)"
  Write-Output "    For Chrome auto-launch instead: .\scripts\flutter_web_dev.ps1 -Device chrome"
}
if (-not $Release) {
  Write-Output "    Debug mode: first load compiles ~1500 modules — wait 1–2 min on white/dark loader."
  Write-Output "    Faster local test: .\scripts\flutter_web_dev.ps1 -Release -Device web-server"
}

Push-Location $MobileDir
try {
  & flutter @args
} finally {
  Pop-Location
}
