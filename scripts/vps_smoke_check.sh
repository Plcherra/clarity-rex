#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-}"
if [ -z "$BASE_URL" ]; then
  echo "Usage: $0 https://your-rex-api-host" >&2
  exit 1
fi

BASE_URL="${BASE_URL%/}"

echo "==> Health"
curl -fsS "$BASE_URL/" | python3 -m json.tool

echo "==> Readiness"
curl -fsS "$BASE_URL/ready" | python3 -m json.tool

echo "==> Smoke checks completed"
