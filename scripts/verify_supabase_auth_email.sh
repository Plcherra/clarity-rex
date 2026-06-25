#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  if [[ -f apps/mobile/.env ]]; then
    set -a
    # shellcheck disable=SC1091
    source apps/mobile/.env
    set +a
  fi
fi

SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "Missing SUPABASE_URL or SUPABASE_ANON_KEY."
  echo "Export them or add them to apps/mobile/.env before running this script."
  exit 1
fi

RANDOM_SUFFIX="$(date +%s)-$RANDOM"
TEST_EMAIL="${AUTH_VERIFY_EMAIL:-clarity-auth-verify+${RANDOM_SUFFIX}@example.com}"
TEST_PASSWORD="${AUTH_VERIFY_PASSWORD:-ClarityAuthVerify!${RANDOM_SUFFIX}}"

echo "==> Verifying Supabase Auth signup email delivery"
echo "    URL:   $SUPABASE_URL"
echo "    Email: $TEST_EMAIL (synthetic; inbox delivery not required for this check)"

RESPONSE_FILE="$(mktemp)"
HTTP_STATUS="$(
  curl -sS \
    -o "$RESPONSE_FILE" \
    -w "%{http_code}" \
    -X POST "$SUPABASE_URL/auth/v1/signup" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}"
)"

BODY="$(cat "$RESPONSE_FILE")"
rm -f "$RESPONSE_FILE"

echo "    HTTP:  $HTTP_STATUS"
echo "    Body:  $BODY"

if [[ "$HTTP_STATUS" == "500" ]] && echo "$BODY" | grep -qi "error sending confirmation email"; then
  echo
  echo "FAIL: Supabase Auth could not send the confirmation email."
  echo "Fix SMTP using docs/SUPABASE_AUTH_EMAIL_SETUP.md"
  echo "Recent auth log hint: Gmail BadCredentials means replace Gmail SMTP with Resend."
  exit 1
fi

if [[ "$HTTP_STATUS" -ge 400 ]]; then
  echo
  echo "FAIL: Signup returned HTTP $HTTP_STATUS"
  exit 1
fi

echo
echo "PASS: signup confirmation email accepted by Supabase Auth"
echo "Next: confirm a real inbox end-to-end using the mobile app and Plan 8 auth smoke."
