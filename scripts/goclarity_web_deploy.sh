#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="${CLOUDFLARE_PAGES_PROJECT:-clarity-landing}"
PUBLIC_SITE_URL="${PUBLIC_SITE_URL:-https://goclarity.app}"
SKIP_BUILD="${SKIP_BUILD:-false}"

if [ "${1:-}" = "--skip-build" ]; then
  SKIP_BUILD=true
fi

if [ "${SKIP_BUILD}" != "true" ]; then
  echo "==> Step 1/3: Flutter web release build"
  "${ROOT_DIR}/scripts/flutter_web_release_build.sh"

  echo "==> Step 2/3: Landing site build"
  PUBLIC_SITE_URL="${PUBLIC_SITE_URL}" "${ROOT_DIR}/scripts/web_release_build.sh"

  echo "==> Step 3/3: Stage Flutter into landing dist"
  "${ROOT_DIR}/scripts/flutter_web_stage_into_landing.sh"
else
  echo "==> Skipping builds (--skip-build)"
fi

if [ ! -d "${ROOT_DIR}/apps/web/dist/app" ]; then
  echo "Missing apps/web/dist/app — run without --skip-build first." >&2
  exit 1
fi

echo "==> Deploying combined site to Cloudflare Pages"
echo "    PUBLIC_SITE_URL=${PUBLIC_SITE_URL}"
echo "    CLOUDFLARE_PAGES_PROJECT=${PROJECT_NAME}"
echo "    If this is your first deploy on this machine, run: npx wrangler login"

cd "${ROOT_DIR}"
npx wrangler pages deploy apps/web/dist \
  --project-name "${PROJECT_NAME}" \
  --branch main

echo "==> Deploy complete"
echo "    Landing: ${PUBLIC_SITE_URL}/"
echo "    PWA app: ${PUBLIC_SITE_URL}/app/"
