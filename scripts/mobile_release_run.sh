#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="${ROOT_DIR}/apps/mobile"

DEVICE_ID="${DEVICE_ID:-00008150-000C03C83A2B401C}"
REX_BACKEND_URL="${REX_BACKEND_URL:-https://api.rexpilot.com}"
REX_CLOUD_VOICE_ENABLED="${REX_CLOUD_VOICE_ENABLED:-true}"
REX_STREAMING_VOICE_ENABLED="${REX_STREAMING_VOICE_ENABLED:-true}"
ENV_FILE="${MOBILE_DIR}/.env"

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

SUPABASE_URL="${SUPABASE_URL:-$(dotenv_value SUPABASE_URL)}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$(dotenv_value SUPABASE_ANON_KEY)}"
REX_BACKEND_URL="${REX_BACKEND_URL:-$(dotenv_value REX_BACKEND_URL)}"
REX_CLOUD_VOICE_ENABLED="${REX_CLOUD_VOICE_ENABLED:-$(dotenv_value REX_CLOUD_VOICE_ENABLED)}"
REX_STREAMING_VOICE_ENABLED="${REX_STREAMING_VOICE_ENABLED:-$(dotenv_value REX_STREAMING_VOICE_ENABLED)}"

if [ -n "${REX_NATIVE_IOS_VOICE_ENABLED:-}" ]; then
  echo "Do not set REX_NATIVE_IOS_VOICE_ENABLED for release testing." >&2
  echo "Use the supported streaming voice path instead." >&2
  exit 1
fi

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Missing SUPABASE_URL or SUPABASE_ANON_KEY." >&2
  echo "Set them in apps/mobile/.env or export them before running this script." >&2
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
