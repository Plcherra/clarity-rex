#!/usr/bin/env bash
# Fail if dist is landing-only or missing Flutter assets (Start on web hangs or shows marketing HTML).
set -euo pipefail

DIST_DIR="${1:?dist directory required}"
APP_DIR="${DIST_DIR}/app"
APP_INDEX="${APP_DIR}/index.html"
ROOT_INDEX="${DIST_DIR}/index.html"

required_files=(
  "index.html"
  "main.dart.js"
  "flutter_bootstrap.js"
  "flutter_service_worker.js"
  "passkeys_bundle.js"
  "manifest.json"
)

if [ ! -f "${APP_INDEX}" ]; then
  echo "Missing Flutter PWA at ${APP_INDEX}." >&2
  echo "Do not deploy landing-only. Run:" >&2
  echo "  ./scripts/goclarity_web_deploy.sh" >&2
  exit 1
fi

if ! grep -q 'flutter_bootstrap' "${APP_INDEX}"; then
  echo "${APP_INDEX} is not the Flutter web app (expected flutter_bootstrap.js)." >&2
  echo "Run the full deploy script so Flutter is staged into apps/web/dist/app/." >&2
  exit 1
fi

if [ -f "${ROOT_INDEX}" ] && cmp -s "${ROOT_INDEX}" "${APP_INDEX}"; then
  echo "${APP_INDEX} is identical to the landing page index.html." >&2
  echo "Stage the Flutter build into dist/app/ before deploy." >&2
  exit 1
fi

for rel in "${required_files[@]}"; do
  path="${APP_DIR}/${rel}"
  if [ ! -f "${path}" ]; then
    echo "Missing Flutter asset: ${path}" >&2
    echo "Run ./scripts/flutter_web_release_build.sh and ./scripts/flutter_web_stage_into_landing.sh" >&2
    exit 1
  fi
done

if grep -qi '<!DOCTYPE html>' "${APP_DIR}/passkeys_bundle.js"; then
  echo "${APP_DIR}/passkeys_bundle.js looks like HTML, not JavaScript." >&2
  exit 1
fi

echo "==> Verified combined dist (landing + Flutter PWA at /app/)"
