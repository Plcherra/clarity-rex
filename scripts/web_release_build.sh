#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="${ROOT_DIR}/apps/web"
PUBLIC_SITE_URL="${PUBLIC_SITE_URL:-https://goclarity.app}"
EXPECT_FLUTTER_STAGE="${EXPECT_FLUTTER_STAGE:-false}"

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is not installed on this machine." >&2
  exit 1
fi

echo "==> Building Clarity landing site"
echo "    PUBLIC_SITE_URL=${PUBLIC_SITE_URL}"

cd "${WEB_DIR}"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi

PUBLIC_SITE_URL="${PUBLIC_SITE_URL}" npm run build

if [ ! -f "${WEB_DIR}/dist/app/index.html" ]; then
  if [ "${EXPECT_FLUTTER_STAGE}" = "true" ]; then
    echo "    (Flutter /app/ will be staged in the next combined-deploy step.)"
  else
    echo "WARNING: dist/app/ is missing - astro build replaced the output directory." >&2
    echo "         'Start on web' will NOT show login until you stage Flutter:" >&2
    echo "           ./scripts/flutter_web_release_build.sh" >&2
    echo "           ./scripts/flutter_web_stage_into_landing.sh" >&2
    echo "         Or run the full deploy: ./scripts/goclarity_web_deploy.sh" >&2
  fi
fi

echo "==> Web release build ready at ${WEB_DIR}/dist"
