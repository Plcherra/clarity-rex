#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_OUT="${ROOT_DIR}/apps/mobile/build/web"
LANDING_DIST="${ROOT_DIR}/apps/web/dist"
APP_DEST="${LANDING_DIST}/app"

if [ ! -d "${FLUTTER_OUT}" ]; then
  echo "Missing Flutter build at ${FLUTTER_OUT}" >&2
  echo "Run ./scripts/flutter_web_release_build.sh first." >&2
  exit 1
fi

if [ ! -d "${LANDING_DIST}" ]; then
  echo "Missing landing dist at ${LANDING_DIST}" >&2
  echo "Run ./scripts/web_release_build.sh first." >&2
  exit 1
fi

echo "==> Staging Flutter PWA into landing dist"
echo "    ${FLUTTER_OUT} -> ${APP_DEST}"

rm -rf "${APP_DEST}"
mkdir -p "${APP_DEST}"
cp -R "${FLUTTER_OUT}/." "${APP_DEST}/"

echo "==> Staged at ${APP_DEST}"
echo "    Deploy with: ./scripts/goclarity_web_deploy.sh --skip-build"
