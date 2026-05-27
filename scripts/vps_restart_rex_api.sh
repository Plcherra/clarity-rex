#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-clarity-rex}"
READY_URL="${READY_URL:-http://127.0.0.1:8011/ready}"

if systemctl list-unit-files rex-backend.service >/dev/null 2>&1; then
  echo "Note: legacy rex-backend.service exists. Canonical service is clarity-rex.service."
fi

echo "==> Updating systemd units"
sudo systemctl daemon-reload

echo "==> Restarting ${SERVICE_NAME}.service"
sudo systemctl restart "${SERVICE_NAME}"
sudo systemctl status "${SERVICE_NAME}" --no-pager

echo "==> Checking readiness at ${READY_URL}"
curl -fsS "${READY_URL}" | python3 -m json.tool

echo "==> ${SERVICE_NAME}.service restarted and readiness responded"
