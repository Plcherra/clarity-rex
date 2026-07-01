#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="${ROOT_DIR}/apps/web"
PUBLIC_SITE_URL="${PUBLIC_SITE_URL:-https://goclarity.app}"

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
npm audit

echo "==> Web release build ready at ${WEB_DIR}/dist"
