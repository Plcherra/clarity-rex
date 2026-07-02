#!/usr/bin/env bash
# Fail if dist is landing-only (Start on web would show marketing HTML at /app/).
set -euo pipefail

DIST_DIR="${1:?dist directory required}"
APP_INDEX="${DIST_DIR}/app/index.html"

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

echo "==> Verified combined dist (landing + Flutter PWA at /app/)"
