#!/usr/bin/env bash
# Verify user_insights migration is applied on the target Supabase project.
set -euo pipefail

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  echo "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before running." >&2
  exit 1
fi

rest_url="${SUPABASE_URL%/}/rest/v1"
response="$(curl -sS -o /tmp/user_insights_probe.json -w '%{http_code}' \
  -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
  "${rest_url}/user_insights?select=id&limit=1")"

if [[ "${response}" == "200" ]]; then
  echo "OK: user_insights table is reachable (HTTP 200)."
  exit 0
fi

echo "FAIL: user_insights probe returned HTTP ${response}." >&2
cat /tmp/user_insights_probe.json >&2 || true
echo "Apply supabase/migrations/20260702000100_create_user_insights.sql on this project." >&2
exit 1
