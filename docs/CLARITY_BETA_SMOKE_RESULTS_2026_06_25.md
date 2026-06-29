# Clarity QA Results - 2026-06-25

Source: `docs/project-completion/08_QA_RELEASE_PLAN.md` (Plan 8 static and regression pass)

This run records **automated** verification only. Real-device manual smoke from
`docs/CLARITY_BETA_SMOKE_RUNBOOK.md` is still pending.

## Final Decision (automated gate)

- [x] Static checks pass: proceed to manual device smoke.
- [ ] Manual P0 smoke pass: not run in this session.
- [ ] Deployment environment `/ready`: not run in this session.

Beta release should wait for manual smoke + deployment checks even though
automated gates are green.

## 1. Static Checks

| Check | Result | Notes |
| --- | --- | --- |
| `flutter analyze` (apps/mobile) | PASS | No issues found |
| `flutter test` (apps/mobile) | PASS | 234 tests |
| `python -m pytest` (services/rex-api) | PASS | 1016 tests |
| Edge Function Deno type checks | PASS | Deno 2.8.3 — all three functions type-check clean |
| Edge Function Deno tests | PASS | 11/11 `categorize-transactions` tests (`--allow-env --allow-net`) |
| `git diff --check` | PASS | No whitespace errors |

## 2. Targeted Regression (Plan 8 §5)

### Backend (134 tests)

`test_readiness`, `test_chat_service`, `test_plaid_routes`, `test_voice_routes`,
`test_voice_stream_routes`, `test_accountability_routes`,
`test_memory_reliability_flow`, `test_chat_service_rex_brain`,
`test_production_config`

Result: **PASS**

### Flutter (88 tests)

`app_routing`, `assistant_navigation`, `chat_controller`, `memory_page`,
`voice_call_controller`, `plaid_account_service`, `financial_read_model_service`,
`accountability_api`, `assistant_financial_context_service`

Result: **PASS**

## 3. Backend Smoke (automated proxy)

Route and readiness behavior covered by pytest (no live VPS in this pass):

| Endpoint / behavior | Automated coverage |
| --- | --- |
| `/ready` status reporting | `test_readiness.py` |
| `/chat` and streaming | `test_chat_service.py` |
| `/conversations` | conversation route tests |
| `/memory` | memory route + reliability tests |
| `/accountability/overview` | `test_accountability_routes.py` |
| `/voice/turn`, `/voice/stream` | voice route + stream tests |
| Plaid link token | `test_plaid_routes.py` |

Live authenticated curl smoke against a running API: **NOT RUN**

## 4. Launch Blocker Static Review

| Blocker | Static review |
| --- | --- |
| Backend secrets in mobile | PASS — no Plaid/Grok/Deepgram/service-role refs in mobile lib |
| Rex Brain experimental routing in production | PASS — guarded in config + tests |
| Voice infinite no-speech loop | PASS — capped at 3 recoveries (controller tests) |
| Memory birthday direct-save regression | PASS — memory turn + chat flow tests |

## 5. Manual Smoke — 2026-06-27 (device)

Tester: Adam. Auth/MFA/sign-out **PASS**. CSV import **partial PASS** with UX bugs. Password reset **FAIL** (ops + redirect).

| Area | Result | Notes |
| --- | --- | --- |
| Auth sign-in / MFA / sign-out | PASS | Working as expected |
| Password reset | FAIL | Email arrives; link opens **localhost** on phone (Supabase Site URL). Gmail flags spam/phishing (default template + no custom domain auth) |
| CSV import (data) | PASS | 66 tx imported; categorization OK; no unknown transactions spotted |
| CSV import (UX) | PARTIAL | Must create manual account first (by design); upload icon missing until navigate away/back; multiple error toasts during import though import succeeds |
| Account balance after CSV | EXPECTED GAP | Manual account shows **$0.00** balance — CSV sets activity, not ending balance unless user enters balance on create |

### Fixes in progress (code)

- Password reset redirect → `https://goclarity.app/auth/reset-password` (mobile + new web page)
- CSV flow: use server account id after create; auto-open file picker; dashboard “Import CSV” starts flow directly
- Docs: `SUPABASE_AUTH_EMAIL_SETUP.md` — Site URL must not be localhost

### Ops required before reset retest

1. Supabase **Site URL** → `https://goclarity.app`
2. Redirect URLs → `/auth/confirmed`, `/auth/reset-password`
3. Deploy web reset page with `PUBLIC_SUPABASE_URL` + `PUBLIC_SUPABASE_ANON_KEY`
4. Resend SMTP + branded template from `supabase/templates/reset-password.html`
5. Request a **new** reset email after URL fix (old links still point at localhost)

Remaining manual smoke (not run): Plaid sandbox, Rex chat/recall/voice, themes on device.

## Known Release Limitations (MVP)

Documented across completion plans — not blockers for starting manual QA:

- Goals: no edit-after-create; accountability signals read-only
- Knows: no manual create (chat/voice only)
- Voice: native iOS path experimental only
- `/ready`: config-based, not live dependency probes
- Legacy `call-openai` Edge Function deprecated but still deployed
- Hybrid semantic chat search post-MVP

## Next Steps

1. Run manual smoke on target device using the beta runbook.
2. Check `/ready` on deployment VPS after restart.
3. Confirm Supabase migrations and Edge Functions deployed to target env.
4. Update this file with manual PASS/FAIL rows and a final beta decision.
