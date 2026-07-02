#!/usr/bin/env bash
set -euo pipefail

# Landing-only deploy breaks /app/ login. Always deploy landing + Flutter PWA together.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${ROOT_DIR}/scripts/goclarity_web_deploy.sh" "$@"
