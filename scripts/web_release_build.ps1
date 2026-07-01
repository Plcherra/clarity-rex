# Build Astro landing site (apps/web/dist).
param(
  [string]$PublicSiteUrl = "https://goclarity.app"
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$WebDir = Join-Path $RootDir "apps\web"

function Invoke-NpmCommand {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  $previousNativeErrors = $null
  if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue) {
    $previousNativeErrors = $global:PSNativeCommandUseErrorActionPreference
    $global:PSNativeCommandUseErrorActionPreference = $false
  }
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & npm @Args
    if ($LASTEXITCODE -ne 0) {
      throw "npm $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }
  } finally {
    $ErrorActionPreference = $previousEap
    if ($null -ne $previousNativeErrors) {
      $global:PSNativeCommandUseErrorActionPreference = $previousNativeErrors
    }
  }
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Error "npm is not installed."
}

Write-Output "==> Building Clarity landing site"
Write-Output "    PUBLIC_SITE_URL=$PublicSiteUrl"

Push-Location $WebDir
try {
  if (Test-Path "package-lock.json") {
    Invoke-NpmCommand ci
  } else {
    Invoke-NpmCommand install
  }
  $env:PUBLIC_SITE_URL = $PublicSiteUrl
  Invoke-NpmCommand run build
} finally {
  Pop-Location
}

Write-Output "==> Web release build ready at $WebDir\dist"
