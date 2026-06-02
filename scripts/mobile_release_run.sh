#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="${ROOT_DIR}/apps/mobile"

DEVICE_ID="${DEVICE_ID:-00008150-000C03C83A2B401C}"
REX_BACKEND_URL="${REX_BACKEND_URL:-https://api.goclarity.app}"
REX_CLOUD_VOICE_ENABLED="${REX_CLOUD_VOICE_ENABLED:-}"
REX_STREAMING_VOICE_ENABLED="${REX_STREAMING_VOICE_ENABLED:-}"
ENV_FILE="${MOBILE_DIR}/.env"
MOBILE_RELEASE_USE_VPS_ENV="${MOBILE_RELEASE_USE_VPS_ENV:-true}"
VPS_SSH_TARGET="${VPS_SSH_TARGET:-rex@209.126.87.50}"
VPS_ENV_FILE="${VPS_ENV_FILE:-/opt/clarity/shared/rex-api.env}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed on this machine." >&2
  echo "Run this helper on the Mac that builds to the iPhone, not on the VPS." >&2
  echo "For the VPS backend, use: ./scripts/vps_restart_rex_api.sh" >&2
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

SUPABASE_URL="${SUPABASE_URL:-$(dotenv_value SUPABASE_URL)}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$(dotenv_value SUPABASE_ANON_KEY)}"
REX_CLOUD_VOICE_ENABLED="${REX_CLOUD_VOICE_ENABLED:-$(dotenv_value REX_CLOUD_VOICE_ENABLED)}"
REX_STREAMING_VOICE_ENABLED="${REX_STREAMING_VOICE_ENABLED:-$(dotenv_value REX_STREAMING_VOICE_ENABLED)}"
apply_vps_public_env
REX_CLOUD_VOICE_ENABLED="${REX_CLOUD_VOICE_ENABLED:-true}"
REX_STREAMING_VOICE_ENABLED="${REX_STREAMING_VOICE_ENABLED:-true}"

if [ -n "${REX_NATIVE_IOS_VOICE_ENABLED:-}" ]; then
  echo "Do not set REX_NATIVE_IOS_VOICE_ENABLED for release testing." >&2
  echo "Use the supported streaming voice path instead." >&2
  exit 1
fi

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Missing SUPABASE_URL or SUPABASE_ANON_KEY." >&2
  echo "Run this helper on the Mac that builds to the iPhone." >&2
  echo "Set them in apps/mobile/.env, export them, or allow VPS fallback." >&2
  echo "VPS fallback reads only SUPABASE_URL and SUPABASE_ANON_KEY from ${VPS_SSH_TARGET}:${VPS_ENV_FILE}." >&2
  echo "Set MOBILE_RELEASE_USE_VPS_ENV=false to disable VPS fallback." >&2
  echo "For the VPS backend, use: ./scripts/vps_restart_rex_api.sh" >&2
  exit 1
fi

command=(
  flutter run
  -d "${DEVICE_ID}"
  --release
  "--dart-define=SUPABASE_URL=${SUPABASE_URL}"
  "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
  "--dart-define=REX_BACKEND_URL=${REX_BACKEND_URL}"
  "--dart-define=REX_CLOUD_VOICE_ENABLED=${REX_CLOUD_VOICE_ENABLED}"
  "--dart-define=REX_STREAMING_VOICE_ENABLED=${REX_STREAMING_VOICE_ENABLED}"
)

if [ "${1:-}" = "--print" ]; then
  printf 'cd %q\n' "${MOBILE_DIR}"
  printf '%q ' "${command[@]}"
  printf '\n'
  exit 0
fi

cd "${MOBILE_DIR}"
exec "${command[@]}"
