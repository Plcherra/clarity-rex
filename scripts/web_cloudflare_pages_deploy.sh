#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="${CLOUDFLARE_PAGES_PROJECT:-clarity-landing}"
PUBLIC_SITE_URL="${PUBLIC_SITE_URL:-https://rexpilot.com}"

echo "==> Building Clarity landing site for Cloudflare Pages"
echo "    PUBLIC_SITE_URL=${PUBLIC_SITE_URL}"
echo "    CLOUDFLARE_PAGES_PROJECT=${PROJECT_NAME}"

cd "${ROOT_DIR}"
PUBLIC_SITE_URL="${PUBLIC_SITE_URL}" ./scripts/web_release_build.sh

echo "==> Deploying apps/web/dist to Cloudflare Pages"
echo "    If this is your first deploy on this machine, run: npx wrangler login"

npx wrangler pages deploy apps/web/dist \
  --project-name "${PROJECT_NAME}" \
  --branch main
