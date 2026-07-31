#!/usr/bin/env bash
# Run Clarity on a connected Android device or emulator (production dart-defines).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOBILE_DIR="${ROOT_DIR}/apps/mobile"

DEVICE_ID="${DEVICE_ID:-}"
EMULATOR_NAME="${EMULATOR_NAME:-clarity_android}"
LAUNCH_EMULATOR="${LAUNCH_EMULATOR:-false}"
BUILD_ONLY="${BUILD_ONLY:-false}"
DEBUG_MODE="${DEBUG_MODE:-false}"
REX_BACKEND_URL="${REX_BACKEND_URL:-https://api.goclarity.app}"
REX_CLOUD_VOICE_ENABLED="${REX_CLOUD_VOICE_ENABLED:-}"
REX_STREAMING_VOICE_ENABLED="${REX_STREAMING_VOICE_ENABLED:-}"
ENV_FILE="${MOBILE_DIR}/.env"
MOBILE_RELEASE_USE_VPS_ENV="${MOBILE_RELEASE_USE_VPS_ENV:-true}"
VPS_SSH_TARGET="${VPS_SSH_TARGET:-clarity}"
VPS_ENV_FILE="${VPS_ENV_FILE:-/opt/clarity/shared/rex-api.env}"

usage() {
  cat <<'EOF'
Usage: ./scripts/android_release_run.sh [options]

Options:
  --print              Print flutter command without running
  --debug              Debug build (default: release, like mobile_release_run.sh)
  --build-only         Build APK/AAB instead of flutter run
  --launch-emulator    Start EMULATOR_NAME when no Android device is connected
  --device ID          Android device id (e.g. emulator-5554)
  --emulator NAME      AVD name for --launch-emulator (default: clarity_android)
  -h, --help           Show this help

Environment:
  DEVICE_ID, EMULATOR_NAME, LAUNCH_EMULATOR=true, BUILD_ONLY=true, DEBUG_MODE=true
  SUPABASE_URL, SUPABASE_ANON_KEY, REX_BACKEND_URL, MOBILE_RELEASE_USE_VPS_ENV
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --print)
      PRINT_ONLY=true
      shift
      ;;
    --debug)
      DEBUG_MODE=true
      shift
      ;;
    --build-only)
      BUILD_ONLY=true
      shift
      ;;
    --launch-emulator)
      LAUNCH_EMULATOR=true
      shift
      ;;
    --device)
      DEVICE_ID="${2:-}"
      shift 2
      ;;
    --emulator)
      EMULATOR_NAME="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

PRINT_ONLY="${PRINT_ONLY:-false}"

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

first_android_device_id() {
  flutter devices 2>/dev/null | awk '
    /android/ && /•/ {
      for (i = 1; i <= NF; i++) {
        if ($i == "•" && $(i+1) != "" && $(i+2) == "•") {
          print $(i+1)
          exit
        }
      }
    }
  '
}

wait_for_android_device() {
  local attempt
  for attempt in $(seq 1 30); do
    DEVICE_ID="$(first_android_device_id)"
    if [ -n "${DEVICE_ID}" ]; then
      return 0
    fi
    sleep 2
  done
  return 1
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

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Missing SUPABASE_URL or SUPABASE_ANON_KEY." >&2
  echo "Set them in apps/mobile/.env, export them, or allow VPS fallback." >&2
  echo "VPS fallback reads SUPABASE_URL and SUPABASE_ANON_KEY from ${VPS_SSH_TARGET}:${VPS_ENV_FILE}." >&2
  echo "Set MOBILE_RELEASE_USE_VPS_ENV=false to disable VPS fallback." >&2
  exit 1
fi

if [ -z "${DEVICE_ID}" ]; then
  DEVICE_ID="$(first_android_device_id)"
fi

if [ -z "${DEVICE_ID}" ] && [ "${LAUNCH_EMULATOR}" = "true" ]; then
  echo "==> Launching Android emulator: ${EMULATOR_NAME}"
  flutter emulators --launch "${EMULATOR_NAME}" >/dev/null 2>&1 || \
    flutter emulators --launch "${EMULATOR_NAME}"
  if ! wait_for_android_device; then
    echo "No Android device appeared after launching ${EMULATOR_NAME}." >&2
    echo "Run: flutter emulators && flutter devices" >&2
    exit 1
  fi
fi

if [ -z "${DEVICE_ID}" ]; then
  echo "No Android device found." >&2
  echo "Connect a device, start an emulator, or rerun with --launch-emulator." >&2
  echo "Run: flutter devices" >&2
  exit 1
fi

define_args=(
  "--dart-define=SUPABASE_URL=${SUPABASE_URL}"
  "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
  "--dart-define=REX_BACKEND_URL=${REX_BACKEND_URL}"
  "--dart-define=REX_CLOUD_VOICE_ENABLED=${REX_CLOUD_VOICE_ENABLED}"
  "--dart-define=REX_STREAMING_VOICE_ENABLED=${REX_STREAMING_VOICE_ENABLED}"
  "--dart-define=SUPABASE_AUTH_REDIRECT_URL=https://goclarity.app/auth/confirmed/"
)

if [ -n "${SENTRY_DSN:-}" ]; then
  define_args+=(
    "--dart-define=SENTRY_DSN=${SENTRY_DSN}"
    "--dart-define=SENTRY_ENVIRONMENT=${SENTRY_ENVIRONMENT}"
  )
fi

if [ "${BUILD_ONLY}" = "true" ]; then
  command=(flutter build apk)
  if [ "${DEBUG_MODE}" != "true" ]; then
    command+=(--release)
  fi
  command+=("${define_args[@]}")
else
  command=(flutter run -d "${DEVICE_ID}")
  if [ "${DEBUG_MODE}" != "true" ]; then
    command+=(--release)
  fi
  command+=("${define_args[@]}")
fi

if [ "${PRINT_ONLY}" = "true" ]; then
  printf 'cd %q\n' "${MOBILE_DIR}"
  printf '%q ' "${command[@]}"
  printf '\n'
  exit 0
fi

echo "==> Android run"
echo "    device=${DEVICE_ID}"
echo "    backend=${REX_BACKEND_URL}"
if [ "${BUILD_ONLY}" = "true" ]; then
  echo "    mode=$([ "${DEBUG_MODE}" = "true" ] && echo debug || echo release) build"
else
  echo "    mode=$([ "${DEBUG_MODE}" = "true" ] && echo debug || echo release) run"
fi

cd "${MOBILE_DIR}"
exec "${command[@]}"
