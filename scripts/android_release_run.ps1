# Run Clarity on a connected Android device or emulator (production dart-defines).
param(
  [string]$DeviceId = "",
  [string]$EmulatorName = "clarity_android",
  [switch]$LaunchEmulator,
  [switch]$Release,
  [switch]$Debug,
  [switch]$BuildOnly,
  [switch]$Print,
  [string]$RexBackendUrl = "",
  [string]$CloudVoice = "",
  [string]$StreamingVoice = "",
  [switch]$SkipVpsEnv
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$MobileDir = Join-Path $RootDir "apps\mobile"
$EnvFile = Join-Path $MobileDir ".env"
$VpsSshTarget = if ($env:VPS_SSH_TARGET) { $env:VPS_SSH_TARGET } else { "clarity" }
$VpsEnvFile = if ($env:VPS_ENV_FILE) { $env:VPS_ENV_FILE } else { "/opt/clarity/shared/rex-api.env" }

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

function Get-VpsPublicEnv {
  if ($SkipVpsEnv) { return @{} }
  if ($env:MOBILE_RELEASE_USE_VPS_ENV -eq "false") { return @{} }
  $ssh = Get-Command ssh -ErrorAction SilentlyContinue
  if (-not $ssh) { return @{} }
  try {
    $remote = & ssh -o BatchMode=yes -o ConnectTimeout=5 $VpsSshTarget @"
awk -F= '
  `$0 !~ /^[[:space:]]*#/ && (`$1 == \"SUPABASE_URL\" || `$1 == \"SUPABASE_ANON_KEY\") {
    value = substr(`$0, index(`$0, \"=\") + 1)
    gsub(/^[[:space:]]+|[[:space:]]+$/, \"\", value)
    gsub(/^\"|\"$/, \"\", value)
    print `$1 \"=\" value
  }
' '$VpsEnvFile'
"@ 2>$null
    if (-not $remote) { return @{} }
    $values = @{}
    foreach ($line in ($remote -split "`n")) {
      if ($line -match "^([^=]+)=(.*)$") {
        $values[$Matches[1]] = $Matches[2]
      }
    }
    return $values
  } catch {
    return @{}
  }
}

function Get-FlutterAndroidDeviceId {
  $output = & flutter devices 2>&1 | Out-String
  foreach ($line in ($output -split "`r?`n")) {
    if ($line -match "android" -and $line -match "•\s+([^\s]+)\s+•\s+android") {
      return $Matches[1]
    }
  }
  return ""
}

function Wait-ForAndroidDevice {
  param([int]$Attempts = 30)
  for ($i = 1; $i -le $Attempts; $i++) {
    $id = Get-FlutterAndroidDeviceId
    if ($id) { return $id }
    Start-Sleep -Seconds 2
  }
  return ""
}

$SupabaseUrl = if ($env:SUPABASE_URL) { $env:SUPABASE_URL } else { Get-DotEnvValue "SUPABASE_URL" }
$SupabaseAnonKey = if ($env:SUPABASE_ANON_KEY) { $env:SUPABASE_ANON_KEY } else { Get-DotEnvValue "SUPABASE_ANON_KEY" }
$vpsEnv = Get-VpsPublicEnv
if (-not $SupabaseUrl -and $vpsEnv.ContainsKey("SUPABASE_URL")) {
  $SupabaseUrl = $vpsEnv["SUPABASE_URL"]
}
if (-not $SupabaseAnonKey -and $vpsEnv.ContainsKey("SUPABASE_ANON_KEY")) {
  $SupabaseAnonKey = $vpsEnv["SUPABASE_ANON_KEY"]
}

if (-not $RexBackendUrl) {
  $RexBackendUrl = Get-DotEnvValue "REX_BACKEND_URL"
  if (-not $RexBackendUrl) { $RexBackendUrl = "https://api.goclarity.app" }
}
if (-not $CloudVoice) {
  $CloudVoice = Get-DotEnvValue "REX_CLOUD_VOICE_ENABLED"
  if (-not $CloudVoice) { $CloudVoice = "true" }
}
if (-not $StreamingVoice) {
  $StreamingVoice = Get-DotEnvValue "REX_STREAMING_VOICE_ENABLED"
  if (-not $StreamingVoice) { $StreamingVoice = "true" }
}

if (-not $SupabaseUrl -or -not $SupabaseAnonKey) {
  throw @"
Missing SUPABASE_URL or SUPABASE_ANON_KEY.
Set them in apps/mobile/.env, as environment variables, or allow VPS fallback via ssh $VpsSshTarget.
Use -SkipVpsEnv to disable VPS fallback.
"@
}

if ($Debug -and $Release) {
  throw "Use only one of -Debug or -Release."
}
$UseRelease = $Release -or -not $Debug

if (-not $DeviceId) {
  $DeviceId = if ($env:DEVICE_ID) { $env:DEVICE_ID } else { Get-FlutterAndroidDeviceId }
}

if (-not $DeviceId -and -not $Print) {
  if ($LaunchEmulator) {
    Write-Output "==> Launching Android emulator: $EmulatorName"
    & flutter emulators --launch $EmulatorName
    $DeviceId = Wait-ForAndroidDevice
  }
}

if (-not $DeviceId) {
  if ($Print) {
    $DeviceId = if ($env:DEVICE_ID) { $env:DEVICE_ID } else { "emulator-5554" }
  } else {
    throw @"
No Android device found.
Connect a device, start an emulator, or rerun with -LaunchEmulator.
Run: flutter devices
"@
  }
}

$defineArgs = @(
  "--dart-define=SUPABASE_URL=$SupabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey",
  "--dart-define=REX_BACKEND_URL=$RexBackendUrl",
  "--dart-define=REX_CLOUD_VOICE_ENABLED=$CloudVoice",
  "--dart-define=REX_STREAMING_VOICE_ENABLED=$StreamingVoice"
)

if ($BuildOnly) {
  $flutterArgs = @("build", "apk")
  if ($UseRelease) { $flutterArgs += "--release" }
  $flutterArgs += $defineArgs
} else {
  $flutterArgs = @("run", "-d", $DeviceId)
  if ($UseRelease) { $flutterArgs += "--release" }
  $flutterArgs += $defineArgs
}

if ($Print) {
  Write-Output "cd $MobileDir"
  Write-Output ("flutter " + ($flutterArgs -join " "))
  exit 0
}

Write-Output "==> Android run"
Write-Output "    device=$DeviceId"
Write-Output "    backend=$RexBackendUrl"
if ($BuildOnly) {
  Write-Output "    mode=$(if ($UseRelease) { 'release build' } else { 'debug build' })"
} else {
  Write-Output "    mode=$(if ($UseRelease) { 'release run' } else { 'debug run' })"
}

Push-Location $MobileDir
try {
  & flutter @flutterArgs
} finally {
  Pop-Location
}
