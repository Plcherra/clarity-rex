#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-clarity-rex}"
READY_URL="${READY_URL:-http://127.0.0.1:8011/ready}"
READY_ATTEMPTS="${READY_ATTEMPTS:-30}"
READY_SLEEP_SECONDS="${READY_SLEEP_SECONDS:-1}"

if systemctl list-unit-files rex-backend.service >/dev/null 2>&1; then
  echo "Note: legacy rex-backend.service exists. Canonical service is clarity-rex.service."
fi

echo "==> Updating systemd units"
sudo systemctl daemon-reload

echo "==> Restarting ${SERVICE_NAME}.service"
sudo systemctl restart "${SERVICE_NAME}"
sudo systemctl status "${SERVICE_NAME}" --no-pager

echo "==> Checking readiness at ${READY_URL}"
ready_response="$(mktemp)"
for attempt in $(seq 1 "${READY_ATTEMPTS}"); do
  if curl -fsS "${READY_URL}" >"${ready_response}"; then
    python3 -m json.tool <"${ready_response}"
    rm -f "${ready_response}"
    echo "==> ${SERVICE_NAME}.service restarted and readiness responded"
    exit 0
  fi

  if ! systemctl is-active --quiet "${SERVICE_NAME}"; then
    echo "Service ${SERVICE_NAME}.service is not active after restart." >&2
    sudo systemctl status "${SERVICE_NAME}" --no-pager >&2 || true
    sudo journalctl -u "${SERVICE_NAME}" -n 80 --no-pager >&2 || true
    rm -f "${ready_response}"
    exit 1
  fi

  echo "Readiness not available yet (${attempt}/${READY_ATTEMPTS}); waiting ${READY_SLEEP_SECONDS}s..."
  sleep "${READY_SLEEP_SECONDS}"
done

echo "Readiness did not respond after ${READY_ATTEMPTS} attempts." >&2
sudo systemctl status "${SERVICE_NAME}" --no-pager >&2 || true
sudo journalctl -u "${SERVICE_NAME}" -n 80 --no-pager >&2 || true
rm -f "${ready_response}"
exit 1
