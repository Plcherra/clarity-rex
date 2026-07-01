#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="${CLOUDFLARE_PAGES_PROJECT:-clarity-landing}"
PUBLIC_SITE_URL="${PUBLIC_SITE_URL:-https://goclarity.app}"

echo "==> Building Clarity landing site for Cloudflare Pages"
echo "    PUBLIC_SITE_URL=${PUBLIC_SITE_URL}"
echo "    CLOUDFLARE_PAGES_PROJECT=${PROJECT_NAME}"

cd "${ROOT_DIR}"
PUBLIC_SITE_URL="${PUBLIC_SITE_URL}" ./scripts/web_release_build.sh

echo "==> Deploying apps/web/dist to Cloudflare Pages"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"${ROOT_DIR}/scripts/wrangler_pages_deploy.sh" "${ROOT_DIR}/apps/web/dist"
