#!/usr/bin/env bash
# Build a TestFlight/App Store IPA with the same production dart-defines as
# scripts/mobile_release_run.sh (Supabase + Rex backend + optional Sentry).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="${ROOT_DIR}/apps/mobile"

BUILD_NAME="${BUILD_NAME:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
REX_BACKEND_URL="${REX_BACKEND_URL:-https://api.goclarity.app}"
REX_CLOUD_VOICE_ENABLED="${REX_CLOUD_VOICE_ENABLED:-}"
REX_STREAMING_VOICE_ENABLED="${REX_STREAMING_VOICE_ENABLED:-}"
ENV_FILE="${MOBILE_DIR}/.env"
MOBILE_RELEASE_USE_VPS_ENV="${MOBILE_RELEASE_USE_VPS_ENV:-true}"
VPS_SSH_TARGET="${VPS_SSH_TARGET:-clarity}"
VPS_ENV_FILE="${VPS_ENV_FILE:-/opt/clarity/shared/rex-api.env}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed on this machine." >&2
  exit 1
fi

dotenv_value() {
  local key="$1"
  if [ ! -f "${ENV_FILE}" ]; then
    return 0
  fi
  awk -F= -v key="${key}" '
    $0 !~ /^[[:space:]]*#/ && $1 == key {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"|"$/, "", value)
      gsub(/^'\''|'\''$/, "", value)
      print value
      exit
    }
  ' "${ENV_FILE}"
}

vps_public_env() {
  if [ "${MOBILE_RELEASE_USE_VPS_ENV}" != "true" ]; then
    return 0
  fi

  ssh "${VPS_SSH_TARGET}" \
    "awk -F= '
      \$0 !~ /^[[:space:]]*#/ && (\$1 == \"SUPABASE_URL\" || \$1 == \"SUPABASE_ANON_KEY\") {
        value = substr(\$0, index(\$0, \"=\") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, \"\", value)
        gsub(/^\"|\"$/, \"\", value)
        gsub(/^'\''|'\''$/, \"\", value)
        print \$1 \"=\" value
      }
    ' '${VPS_ENV_FILE}'" 2>/dev/null || true
}

apply_vps_public_env() {
  if { [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_ANON_KEY:-}" ]; }; then
    return 0
  fi

  local line key value
  while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"
    case "${key}" in
      SUPABASE_URL)
        SUPABASE_URL="${SUPABASE_URL:-${value}}"
        ;;
      SUPABASE_ANON_KEY)
        SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${value}}"
        ;;
    esac
  done < <(vps_public_env)
}

pubspec_build_number() {
  awk '
    /^version:/ {
      if (match($0, /\+([0-9]+)/, m)) {
        print m[1]
        exit
      }
    }
  ' "${MOBILE_DIR}/pubspec.yaml"
}

SUPABASE_URL="${SUPABASE_URL:-$(dotenv_value SUPABASE_URL)}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$(dotenv_value SUPABASE_ANON_KEY)}"
REX_CLOUD_VOICE_ENABLED="${REX_CLOUD_VOICE_ENABLED:-$(dotenv_value REX_CLOUD_VOICE_ENABLED)}"
REX_STREAMING_VOICE_ENABLED="${REX_STREAMING_VOICE_ENABLED:-$(dotenv_value REX_STREAMING_VOICE_ENABLED)}"
SENTRY_DSN="${SENTRY_DSN:-$(dotenv_value SENTRY_DSN)}"
SENTRY_ENVIRONMENT="${SENTRY_ENVIRONMENT:-$(dotenv_value SENTRY_ENVIRONMENT)}"
apply_vps_public_env
REX_CLOUD_VOICE_ENABLED="${REX_CLOUD_VOICE_ENABLED:-true}"
REX_STREAMING_VOICE_ENABLED="${REX_STREAMING_VOICE_ENABLED:-true}"
SENTRY_ENVIRONMENT="${SENTRY_ENVIRONMENT:-production}"

if [ -z "${BUILD_NUMBER}" ]; then
  current="$(pubspec_build_number)"
  if [ -n "${current}" ]; then
    BUILD_NUMBER="$((current + 1))"
  else
    BUILD_NUMBER="1"
  fi
fi

if [ -n "${REX_NATIVE_IOS_VOICE_ENABLED:-}" ]; then
  echo "Do not set REX_NATIVE_IOS_VOICE_ENABLED for release builds." >&2
  exit 1
fi

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Missing SUPABASE_URL or SUPABASE_ANON_KEY." >&2
  echo "Set them in apps/mobile/.env, export them, or allow VPS fallback." >&2
  echo "VPS fallback reads only SUPABASE_URL and SUPABASE_ANON_KEY from ${VPS_SSH_TARGET}:${VPS_ENV_FILE}." >&2
  exit 1
fi

# Keep pubspec in sync with the IPA build number for the next bump.
python3 - <<PY
from pathlib import Path
path = Path("${MOBILE_DIR}/pubspec.yaml")
text = path.read_text()
lines = []
for line in text.splitlines(keepends=True):
    if line.startswith("version:"):
        lines.append(f"version: ${BUILD_NAME}+${BUILD_NUMBER}\n")
    else:
        lines.append(line)
path.write_text("".join(lines))
PY

command=(
  flutter build ipa
  "--build-name=${BUILD_NAME}"
  "--build-number=${BUILD_NUMBER}"
  "--dart-define=SUPABASE_URL=${SUPABASE_URL}"
  "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
  "--dart-define=REX_BACKEND_URL=${REX_BACKEND_URL}"
  "--dart-define=REX_CLOUD_VOICE_ENABLED=${REX_CLOUD_VOICE_ENABLED}"
  "--dart-define=REX_STREAMING_VOICE_ENABLED=${REX_STREAMING_VOICE_ENABLED}"
  "--dart-define=SUPABASE_AUTH_REDIRECT_URL=https://goclarity.app/auth/confirmed/"
)

if [ -n "${SENTRY_DSN:-}" ]; then
  command+=(
    "--dart-define=SENTRY_DSN=${SENTRY_DSN}"
    "--dart-define=SENTRY_ENVIRONMENT=${SENTRY_ENVIRONMENT}"
  )
fi

echo "Building IPA ${BUILD_NAME} (${BUILD_NUMBER}) with production dart-defines..."
echo "  SUPABASE_URL=${SUPABASE_URL}"
echo "  REX_BACKEND_URL=${REX_BACKEND_URL}"
echo "  SENTRY_ENVIRONMENT=${SENTRY_ENVIRONMENT}"

cd "${MOBILE_DIR}"
"${command[@]}"

echo
echo "IPA ready: ${MOBILE_DIR}/build/ios/ipa/clarity.ipa"
echo "Upload via Xcode Organizer or Transporter, then set this build on TestFlight groups V1 / v1_ex."
