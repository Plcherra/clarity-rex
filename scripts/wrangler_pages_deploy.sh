#!/usr/bin/env bash
# Shared Cloudflare Pages deploy via wrangler.
# Wrangler 4+ requires Node 22; pin v3 for Node 18 LTS (typical VPS).
set -euo pipefail

WRANGLER_VERSION="${WRANGLER_VERSION:-3}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${1:-${ROOT_DIR}/apps/web/dist}"
PROJECT_NAME="${CLOUDFLARE_PAGES_PROJECT:-clarity-landing}"
BRANCH="${CLOUDFLARE_PAGES_BRANCH:-main}"

if [ ! -f "${DIST_DIR}/index.html" ]; then
  echo "Missing ${DIST_DIR}/index.html — build the site first." >&2
  exit 1
fi

echo "==> Cloudflare Pages deploy"
echo "    wrangler@${WRANGLER_VERSION}"
echo "    dist=${DIST_DIR}"
echo "    project=${PROJECT_NAME}"
echo "    branch=${BRANCH}"
echo "    First time? npx wrangler@${WRANGLER_VERSION} login"

cd "${ROOT_DIR}"
npx "wrangler@${WRANGLER_VERSION}" pages deploy "${DIST_DIR}" \
  --project-name "${PROJECT_NAME}" \
  --branch "${BRANCH}"
