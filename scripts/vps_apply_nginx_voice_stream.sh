#!/usr/bin/env bash
# Ensure live nginx proxies WebSocket upgrades for Clarity streaming voice.
# Safe to re-run: skips when /voice/stream is already present.
#
# Usage on VPS (from /opt/clarity/current after git pull):
#   bash scripts/vps_apply_nginx_voice_stream.sh
#
# Debug only (print live site file, no write):
#   bash scripts/vps_apply_nginx_voice_stream.sh --dump
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${ROOT_DIR}/deploy/templates/nginx-clarity-rex.conf"
HTTP_SNIPPET="${ROOT_DIR}/deploy/templates/nginx-clarity-rex-http-snippet.conf"
LOG_FORMAT_DEST="/etc/nginx/conf.d/clarity-log-format.conf"
VOICE_MARKER='location /voice/stream'
BACKUP_DIR="${BACKUP_DIR:-/tmp/clarity-nginx-backups}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DUMP_ONLY=0

if [[ "${1:-}" == "--dump" ]]; then
  DUMP_ONLY=1
fi

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

CANDIDATES=()
while IFS= read -r line; do
  [[ -n "${line}" ]] && CANDIDATES+=("${line}")
done < <(
  # Only active sites — never rewrite dated *.bak* copies under sites-available.
  sudo grep -RIlE 'proxy_pass[[:space:]].*127\.0\.0\.1:8011|server_name[[:space:]].*api\.goclarity\.app|server_name[[:space:]].*api\.rexpilot\.com' \
    /etc/nginx/sites-enabled 2>/dev/null || true
)

FILTERED=()
for conf in "${CANDIDATES[@]}"; do
  base="$(basename "${conf}")"
  if [[ "${conf}" == "${LOG_FORMAT_DEST}" || "${base}" == *clarity-log-format* ]]; then
    continue
  fi
  if [[ "${base}" == *.bak* || "${base}" == *~ ]]; then
    continue
  fi
  FILTERED+=("${conf}")
done
CANDIDATES=("${FILTERED[@]}")

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "No nginx site proxying :8011 or naming api.goclarity.app was found." >&2
  echo "Dump sites-enabled:" >&2
  sudo ls -la /etc/nginx/sites-enabled /etc/nginx/sites-available 2>&1 || true
  exit 1
fi

if [[ "${DUMP_ONLY}" -eq 1 ]]; then
  for conf in "${CANDIDATES[@]}"; do
    echo "===== ${conf} ====="
    sudo sed -n '1,240p' "${conf}"
    echo
  done
  exit 0
fi

echo "==> Installing log_format snippet (http context)"
sudo cp "${HTTP_SNIPPET}" "${LOG_FORMAT_DEST}"

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
block = os.environ["VOICE_BLOCK"].rstrip() + "\n"

if "location /voice/stream" in text:
    sys.stdout.write(text)
    sys.exit(0)


def brace_blocks(source: str, keyword: str):
    """Yield (start, end_inclusive) for top-level `keyword { ... }` blocks."""
    i = 0
    while True:
        m = re.search(rf"(?m)^[ \t]*{keyword}\b[^{{]*\{{", source[i:])
        if not m:
            return
        start = i + m.start()
        brace_at = i + m.end() - 1
        depth = 0
        for j in range(brace_at, len(source)):
            ch = source[j]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    yield start, j
                    i = j + 1
                    break
        else:
            raise SystemExit(f"Unbalanced braces while scanning {keyword} in {path}")


def looks_like_api_server(block: str) -> bool:
    if "proxy_pass" not in block:
        return False
    if "127.0.0.1:8011" in block or "localhost:8011" in block:
        return True
    if re.search(r"server_name[^;]*(api\.goclarity\.app|api\.rexpilot\.com)", block):
        return True
    # Upstream alias (proxy_pass http://clarity;) in a file already selected
    # because :8011 or api.* appeared somewhere in the candidate path.
    return bool(re.search(r"proxy_pass\s+https?://", block))


def indent_of(line: str) -> str:
    return re.match(r"[ \t]*", line).group(0)


inserted = False
for start, end in brace_blocks(text, "server"):
    server = text[start : end + 1]
    if not looks_like_api_server(server):
        continue

    # Prefer inserting immediately before the catch-all location / { ... }
    # that proxies the API (any proxy_pass style / upstream name).
    loc_matches = list(
        re.finditer(
            r"(?m)^([ \t]*)location[ \t]+/[ \t]*\{",
            server,
        )
    )
    insert_at = None
    server_indent = "    "
    for loc in loc_matches:
        loc_start = loc.start()
        # Find end of this location block inside server.
        depth = 0
        rel = server[loc_start:]
        brace_rel = rel.find("{")
        for j in range(brace_rel, len(rel)):
            if rel[j] == "{":
                depth += 1
            elif rel[j] == "}":
                depth -= 1
                if depth == 0:
                    loc_body = rel[: j + 1]
                    break
        else:
            continue
        if "proxy_pass" in loc_body:
            insert_at = start + loc_start
            server_indent = loc.group(1)
            break

    if insert_at is None:
        # Fallback: before the closing brace of this server block.
        insert_at = end
        # Infer indent from prior non-empty line.
        prior = text[:end].rstrip().splitlines()
        server_indent = indent_of(prior[-1]) if prior else "    "
        if server_indent == "":
            server_indent = "    "

    indented_block = "\n".join(
        (server_indent + line if line else line) for line in block.splitlines()
    )
    if not indented_block.endswith("\n"):
        indented_block += "\n"
    # Keep a blank line after the inserted location.
    indented_block += "\n"

    text = text[:insert_at] + indented_block + text[insert_at:]
    inserted = True
    break

if not inserted:
    # Last-resort: append a dedicated server snippet is too dangerous.
    # Dump a short fingerprint so ops can see why matching failed.
    preview = "\n".join(text.splitlines()[:80])
    raise SystemExit(
        "Could not find a safe insert point in "
        f"{path}. First 80 lines:\n{preview}\n"
        "Re-run with: bash scripts/vps_apply_nginx_voice_stream.sh --dump"
    )

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

echo "==> Reloading nginx"
sudo systemctl reload nginx

echo "==> Verify"
if sudo nginx -T 2>&1 | grep -qF "${VOICE_MARKER}"; then
  sudo nginx -T 2>&1 | grep -n 'voice/stream\|Upgrade\|Connection' | head -n 40
  echo "==> voice/stream location is live"
else
  echo "voice/stream still missing after apply." >&2
  exit 1
fi

sudo touch /var/log/nginx/clarity-rex-voice.access.log
sudo chmod 644 /var/log/nginx/clarity-rex-voice.access.log || true
echo "==> Log file ready: /var/log/nginx/clarity-rex-voice.access.log"
echo "==> After a spoken turn, expect WebSocket lines in journalctl and rows in that log."
