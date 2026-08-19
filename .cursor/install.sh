#!/usr/bin/env bash
# Idempotent repository bootstrap for the Clarity monorepo Cloud Agent
# environment. Runs after the source tree is checked out. Sets up all three
# stacks: the Rex FastAPI backend, the Astro web landing site, and the Flutter
# mobile app. Safe to re-run.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> rex-api (Python / FastAPI)"
pushd services/rex-api >/dev/null
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
./.venv/bin/pip install --upgrade pip
./.venv/bin/pip install -r requirements.txt
# Minimal development .env. The full .env.example ships secret placeholders and
# leaves three REX_AUTO_PROPOSALS_* booleans empty, which pydantic-settings
# rejects at startup. In development mode the backend boots with defaults and a
# fake dev auth user, so only APP_ENVIRONMENT + CORS origins are needed locally.
if [ ! -f .env ]; then
  cat > .env <<'EOF'
APP_ENVIRONMENT=development
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://localhost:8080,http://localhost:8081,http://127.0.0.1:4321,http://localhost:4321
GROK_BASE_URL=https://api.x.ai/v1
EOF
fi
popd >/dev/null

echo "==> apps/web (Node / Astro)"
pushd apps/web >/dev/null
npm ci
if [ ! -f .env ]; then
  cp .env.example .env
fi
popd >/dev/null

echo "==> apps/mobile (Flutter)"
pushd apps/mobile >/dev/null
if [ ! -f .env ]; then
  cp .env.example .env
fi
flutter pub get
popd >/dev/null

echo "==> install complete"
