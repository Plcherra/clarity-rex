#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "==> Checking git-visible secrets"
if git status --short --ignored | grep -E '(^!!|^[?][?]) .*[.]env$|(^!!|^[?][?]) .*[.]env[.]' >/dev/null; then
  echo "Local .env files may exist, but they must stay ignored."
fi
if git ls-files | grep -E '(^|/)[.]env($|[.])'; then
  echo "Refusing to continue: a real .env file is tracked." >&2
  exit 1
fi

echo "==> Flutter analyze"
cd "$ROOT_DIR/apps/mobile"
flutter analyze

echo "==> Flutter tests"
flutter test

echo "==> Android debug build"
flutter build apk --debug

echo "==> Rex backend compile check"
cd "$ROOT_DIR/services/rex-api"
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi
. .venv/bin/activate
pip install -r requirements.txt
python -m compileall app

echo "==> Rex backend tests"
python -m pytest

echo "==> Pre-deploy checks passed"
