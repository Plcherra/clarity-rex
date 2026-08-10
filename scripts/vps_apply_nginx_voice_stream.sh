#!/usr/bin/env bash
# Ensure live nginx proxies WebSocket upgrades for Clarity streaming voice.
# Safe to re-run: skips when /voice/stream is already present.
#
# Usage on VPS (from /opt/clarity/current after git pull):
#   bash scripts/vps_apply_nginx_voice_stream.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${ROOT_DIR}/deploy/templates/nginx-clarity-rex.conf"
HTTP_SNIPPET="${ROOT_DIR}/deploy/templates/nginx-clarity-rex-http-snippet.conf"
LOG_FORMAT_DEST="/etc/nginx/conf.d/clarity-log-format.conf"
VOICE_MARKER='location /voice/stream'
BACKUP_DIR="${BACKUP_DIR:-/tmp/clarity-nginx-backups}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

if [[ ! -f "${TEMPLATE}" ]]; then
  echo "Missing nginx template: ${TEMPLATE}" >&2
  exit 1
fi

if [[ ! -f "${HTTP_SNIPPET}" ]]; then
  echo "Missing http snippet: ${HTTP_SNIPPET}" >&2
  exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
  echo "nginx is not installed on this host." >&2
  exit 1
fi

echo "==> Installing log_format snippet (http context)"
sudo cp "${HTTP_SNIPPET}" "${LOG_FORMAT_DEST}"

CANDIDATES=()
while IFS= read -r line; do
  [[ -n "${line}" ]] && CANDIDATES+=("${line}")
done < <(
  sudo grep -RIlE 'proxy_pass[[:space:]]+http://127\.0\.0\.1:8011|server_name[[:space:]].*api\.goclarity\.app' \
    /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null || true
)

# Exclude the log-format snippet itself from patch targets.
FILTERED=()
for conf in "${CANDIDATES[@]}"; do
  if [[ "${conf}" == "${LOG_FORMAT_DEST}" ]]; then
    continue
  fi
  FILTERED+=("${conf}")
done
CANDIDATES=("${FILTERED[@]}")

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "No nginx site proxying :8011 or naming api.goclarity.app was found." >&2
  echo "Install from ${TEMPLATE} (preserve TLS lines from the live site), then re-run." >&2
  exit 1
fi

VOICE_BLOCK="$(
  TEMPLATE_PATH="${TEMPLATE}" python3 - <<'PY'
from pathlib import Path
import os
import re
import sys

text = Path(os.environ["TEMPLATE_PATH"]).read_text(encoding="utf-8")
match = re.search(
    r"location /voice/stream \{.*?\n    \}",
    text,
    flags=re.S,
)
if not match:
    raise SystemExit("Could not extract location /voice/stream from template")
sys.stdout.write(match.group(0))
PY
)"

patched_any=0
mkdir -p "${BACKUP_DIR}"

patch_conf() {
  local conf="$1"
  local tmp
  tmp="$(mktemp)"
  if ! CONF_PATH="${conf}" VOICE_BLOCK="${VOICE_BLOCK}" sudo -E python3 - <<'PY' >"${tmp}"
from pathlib import Path
import os
import re
import sys

path = Path(os.environ["CONF_PATH"])
text = path.read_text(encoding="utf-8")
block = os.environ["VOICE_BLOCK"].rstrip() + "\n\n"

pattern = re.compile(
    r"(^[ \t]*location[ \t]+/[ \t]*\{[^\n]*\n"
    r"(?:[ \t]+.*\n)*?"
    r"[ \t]*proxy_pass[ \t]+http://127\.0\.0\.1:8011;[^\n]*\n"
    r"(?:[ \t]+.*\n)*?"
    r"[ \t]*\})",
    flags=re.M,
)
match = pattern.search(text)
if match:
    start = match.start()
    text = text[:start] + block + text[start:]
else:
    server_match = re.search(
        r"server\s*\{(?:[^{}]|\{[^{}]*\})*8011(?:[^{}]|\{[^{}]*\})*\}",
        text,
        flags=re.S,
    )
    if not server_match:
        raise SystemExit(f"Could not find a safe insert point in {path}")
    end = server_match.end() - 1
    indented = "    " + block.replace("\n", "\n    ").rstrip() + "\n"
    text = text[:end] + "\n" + indented + text[end:]

sys.stdout.write(text)
PY
  then
    rm -f "${tmp}"
    return 1
  fi

  sudo cp "${tmp}" "${conf}"
  rm -f "${tmp}"
  echo "Patched ${conf}"
}

for conf in "${CANDIDATES[@]}"; do
  if sudo grep -qF "${VOICE_MARKER}" "${conf}"; then
    echo "==> Already present in ${conf}"
    continue
  fi

  backup="${BACKUP_DIR}/$(basename "${conf}").${TIMESTAMP}.bak"
  echo "==> Backing up ${conf} -> ${backup}"
  sudo cp -a "${conf}" "${backup}"

  echo "==> Inserting ${VOICE_MARKER} into ${conf}"
  patch_conf "${conf}"
  patched_any=1
done

echo "==> nginx -t"
sudo nginx -t

if [[ "${patched_any}" -eq 1 ]]; then
  echo "==> Reloading nginx"
  sudo systemctl reload nginx
else
  # log_format snippet may still be new
  echo "==> Reloading nginx (log format / verify)"
  sudo systemctl reload nginx
fi

echo "==> Verify"
if sudo nginx -T 2>&1 | grep -qF "${VOICE_MARKER}"; then
  sudo nginx -T 2>&1 | grep -n 'voice/stream' | head -n 20
  echo "==> voice/stream location is live"
else
  echo "voice/stream still missing after apply." >&2
  exit 1
fi

# Ensure the dedicated access log path exists (nginx creates it on first hit,
# but missing file after a speak attempt means the location was never used).
sudo touch /var/log/nginx/clarity-rex-voice.access.log
sudo chmod 644 /var/log/nginx/clarity-rex-voice.access.log || true
echo "==> Log file ready: /var/log/nginx/clarity-rex-voice.access.log"
echo "==> After a spoken turn, expect WebSocket lines in journalctl and rows in that log."
